from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException, Path
from pydantic import BaseModel, Field


DB_PATH = os.getenv("DB_PATH", "/data/app.db")

app = FastAPI(title="Product Catalog API", version="1.0.0")

# модель для добавления товара в заказ
# содержит:
# - id товара
# - количество добавляемых товаров
class AddItemBody(BaseModel):
    product_id: int = Field(..., ge=1)
    quantity: int = Field(..., ge=1)


# модель ответа при добавлении товара в заказ
# содержит: 
# - id заказа
# - id товара 
# - добавленное количество
# - текущее количество товара в заказе
# - оставшееся количество товаров
class AddItemResponse(BaseModel):
    order_id: int
    product_id: int
    added_quantity: int
    order_item_quantity: int
    product_remaining_quantity: int

# соединение с БД sqlite3
def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=30, isolation_level=None)
    conn.row_factory = sqlite3.Row
    # important pragmas
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    return conn


@contextmanager
def db() -> sqlite3.Connection:
    conn = _connect()
    try:
        yield conn
    finally:
        conn.close()


def init_schema(conn: sqlite3.Connection) -> None:
    # схема из файла init.sql
    conn.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY,
            name VARCHAR NOT NULL,
            parent_id INTEGER REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
            CONSTRAINT check_category_not_self_parent CHECK (parent_id IS NULL OR parent_id <> id),
            CONSTRAINT check_category_unique UNIQUE (name, parent_id)
        );

        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY,
            name VARCHAR NOT NULL,
            quantity INTEGER,
            price INTEGER,
            category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
            CONSTRAINT check_product_non_neg_quanity CHECK (quantity >= 0),
            CONSTRAINT check_product_non_neg_price CHECK (price >= 0)
        );

        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY,
            name VARCHAR NOT NULL,
            address VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY,
            created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
            customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT
        );

        CREATE TABLE IF NOT EXISTS orders_products (
            order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
            product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
            quantity INTEGER NOT NULL,
            PRIMARY KEY(order_id, product_id),
            CONSTRAINT check_product_quantity_pos CHECK (quantity > 0)
        );

        -- optional but useful in real life
        CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
        CREATE INDEX IF NOT EXISTS idx_orders_products_product_id ON orders_products(product_id);
        """
    )

# заполнение БД, если она пустая
def seed_if_empty(conn: sqlite3.Connection) -> None:
    # Если в products уже есть записи, считаем что БД заполнена
    row = conn.execute("SELECT 1 FROM products LIMIT 1;").fetchone()
    if row is not None:
        return

    seed_path = os.getenv("SEED_PATH", "/app/insert.sql")
    if not os.path.exists(seed_path):
        return

    with open(seed_path, "r", encoding="utf-8") as f:
        conn.executescript(f.read())


# инициализация БД при старте приложения
@app.on_event("startup")
def _startup() -> None:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with db() as conn:
        init_schema(conn)
        seed_if_empty(conn)


# обработчик POST запроса для добавления товара в заказ
@app.post(
    "/orders/{order_id}/items",
    response_model=AddItemResponse,
    summary="Добавить товар в заказ",
)
def add_product_to_order(
    order_id: int = Path(..., ge=1),
    body: AddItemBody = ...,
) -> AddItemResponse:
    product_id = body.product_id
    qty = body.quantity

    with db() as conn:
        cur = conn.cursor()

        # Single transaction to keep inventory + order items consistent
        cur.execute("BEGIN IMMEDIATE;")
        try:
            # 1) Проверить, что заказ существует
            # если нет - ошибка 404 - Not Found
            row = cur.execute("SELECT 1 FROM orders WHERE id = ?;", (order_id,)).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail=f"Заказ {order_id} не найден")

            # 2) Проверить, что товар существует
            # если нет - ошибка 404 - Not Found
            row = cur.execute("SELECT 1 FROM products WHERE id = ?;", (product_id,)).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail=f"Товар {product_id} не найден")

            # 3) Уменьшить количество товара на складе, если достаточно
            res = cur.execute(
                """
                UPDATE products
                SET quantity = quantity - ?
                WHERE id = ? AND quantity >= ?;
                """,
                (qty, product_id, qty),
            )
            if res.rowcount != 1:
                # если не удалось обновить (недостаточно товара), ошибка 409 - Conflict
                raise HTTPException(status_code=409, detail="Недостаточно товара на складе")

            # 4) Операция UPSERT:
            # если товар уже в заказе, увеличить количество,
            # иначе вставить новую запись в orders_products        
            cur.execute(
                """
                INSERT INTO orders_products(order_id, product_id, quantity)
                VALUES (?, ?, ?)
                ON CONFLICT(order_id, product_id)
                DO UPDATE SET quantity = orders_products.quantity + excluded.quantity;
                """,
                (order_id, product_id, qty),
            )

            # 5) Подсчитать итоговое количество товара в заказе
            item_qty = cur.execute(
                "SELECT quantity FROM orders_products WHERE order_id = ? AND product_id = ?;",
                (order_id, product_id),
            ).fetchone()["quantity"]
            # 6) Подсчитать оставшееся количество товаров
            remaining = cur.execute(
                "SELECT quantity FROM products WHERE id = ?;",
                (product_id,),
            ).fetchone()["quantity"]

            cur.execute("COMMIT;")

            # 7) Вернуть ответ с деталями операции
            return AddItemResponse(
                order_id=order_id,
                product_id=product_id,
                added_quantity=qty,
                order_item_quantity=item_qty,
                product_remaining_quantity=remaining,
            )

        # ловим исключения для отката транзакции и возврата корректного кода ошибки
        except HTTPException:
            cur.execute("ROLLBACK;")
            raise
        except sqlite3.IntegrityError as e:
            # FK violations etc.
            cur.execute("ROLLBACK;")
            raise HTTPException(status_code=400, detail=f"Integrity error: {e}")
        except Exception as e:
            cur.execute("ROLLBACK;")
            raise HTTPException(status_code=500, detail=f"Unexpected error: {e}")
