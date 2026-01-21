PRAGMA foreign_keys = ON;

CREATE TABLE categories (
	id INTEGER PRIMARY KEY,
	name VARCHAR NOT NULL,
	parent_id INTEGER REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE, -- удалить нельзя если есть подкатегории
	CONSTRAINT check_category_not_self_parent CHECK (parent_id IS NULL OR parent_id <> id), -- категория не может иметь саму себя в качестве подкатегории
	CONSTRAINT check_category_unique UNIQUE (name, parent_id) -- не может быть две разных подкатегории с одинаковыми названиями
);

CREATE TABLE products (
	id INTEGER PRIMARY KEY,
	name VARCHAR NOT NULL,
	quantity INTEGER, -- должно быть >= 0
	price INTEGER, -- должно быть >= 0
	category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT, -- нельзя удалить категорию если у неё есть товары
	CONSTRAINT check_product_non_neg_quanity CHECK (quantity >= 0),
	CONSTRAINT check_product_non_neg_price CHECK (price >= 0)
);

CREATE TABLE customers (
	id INTEGER PRIMARY KEY,
	name VARCHAR NOT NULL,
	address VARCHAR NOT NULL
);

CREATE TABLE orders (
	id INTEGER PRIMARY KEY,
	created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
	customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT -- нельзя удалить категорию у которой есть заказы
);

-- разрешение связи "многие ко многим": в одном заказе м.б. много товаров и наоборот
CREATE TABLE orders_products (
	order_id INTEGER NOT NULL REFERENCES orders(id)  ON DELETE CASCADE, -- удалилить заказ = удалились позиции
	product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT, -- удалить товар нельзя если он есть в заказах
	quantity INTEGER NOT NULL,
	PRIMARY KEY(order_id, product_id),
	CONSTRAINT check_product_quantity_pos CHECK (quantity > 0)
);