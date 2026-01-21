-- 2.3.2. Проанализировать написанный в п. 2.3.1 запрос и структуру БД. Предложить
-- варианты оптимизации этого запроса и общей схемы данных для повышения
-- производительности системы в условиях роста данных (тысячи заказов в день)

-- используем для анализа запроса команду EXPLAIN:

EXPLAIN SELECT * FROM top5_view;

-- вывод получается большим, здесь нужно выделить следущее:
-- эти строки: 
-- OpenRead 5 root=7 iDb=0; orders_products 
-- Rewind 5 
-- Next 5 
-- означают, что курсор (номер 5) использует полный перебор таблицы orders_products

-- orders_products перебираются, так как:
-- читаются эти таблицы:
-- OpenRead	4	root=4 iDb=0; products, и далее SeekRowid 4 - точечное обращение по первичному ключу
-- OpenRead	6	root=6 iDb=0; orders, и далее SeekRowid 6 - точечное обращение по первичному ключу

-- а далее для каждой найденно строки orders используется условие created_at >= (текущая дата - 1 месяц):
-- Function	7	13	12	datetime(-1)	0	r[12]=func(r[13..15])
-- Lt	12	29	11	BINARY-8	82	if r[11]<r[12] goto 29
-- Rowid	4	21	0		0	r[21]=products.rowid
-- фильтрация по created_at после прохода всей таблицы orders_products - очень не эффективно -> нужен индекс orders(created_at):

CREATE INDEX idx_orders_created_at ON orders(created_at);

-- после повторного EXPLAIN видим снова полный перебор таблицы orders_products:
-- OpenRead	5	7	0	3	0	root=7 iDb=0; orders_products
-- OpenRead	4	4	0	5	0	root=4 iDb=0; products
-- OpenRead	6	6	0	2	0	root=6 iDb=0; orders
-- Rewind	5	30	0		0	
-- Next	5
-- это происходит из-за самого запроса. Модифицируем его так, чтобы сначала отблирались заказы за последний месяц:

WITH last_month_orders AS (
 SELECT id FROM orders WHERE created_at >= datetime('now', 'localtime', '-1 month')
),

top5 AS (
SELECT 
	p.id AS product_id,
	p.name AS product_name,
	p.category_id AS product_category_id,
	SUM(op.quantity) AS total_bought
FROM
	products p JOIN orders_products op
		ON p.id = op.product_id
			   JOIN last_month_orders lmo
		ON op.order_id = lmo.id
GROUP BY p.id
ORDER BY total_bought DESC
LIMIT 5
)

-- заменим в итоговом view top5 на выражение выше и снова посмотрим EXPLAIN.
-- теперь видим такое:
-- OpenRead	5	7	0	3	0	root=7 iDb=0; orders_products
-- OpenRead	4	4	0	5	0	root=4 iDb=0; products
-- OpenRead	7	6	0	2	0	root=6 iDb=0; orders
-- Rewind	5	30	0		0	
-- Column	5	1	9		0	r[9]= cursor 5 column 1
-- SeekRowid	4	29	9		0	intkey=r[9]
-- Column	5	0	10		0	r[10]= cursor 5 column 0
-- SeekRowid	7	29	10		0	intkey=r[10]

-- по прежнему происходит перебор таблицы orders_products.
-- добавим отдельный индекс orders_products(product_id), 
-- так как самом поле есть только в префиксе индекса PK(order_id, product_id)
-- это должно ускорить агрегацию по этому полю:

CREATE INDEX idx_orders_products_product_id ON orders_products(product_id);

-- снова выполним EXPLAIN, снова видим:

-- OpenRead	5	7	0	3	0	root=7 iDb=0; orders_products
-- OpenRead	4	4	0	5	0	root=4 iDb=0; products
-- OpenRead	7	6	0	2	0	root=6 iDb=0; orders
-- Rewind	5	30	0		0	
-- Column	5	1	9		0	r[9]= cursor 5 column 1
-- SeekRowid	4	29	9		0	intkey=r[9]
-- Column	5	0	10		0	r[10]= cursor 5 column 0
-- SeekRowid	7	29	10		0	intkey=r[10]

-- Итоги:
-- судя по всему, планировщик SQLite не использует индексы idx_orders_created_at и idx_orders_products_product_id 
-- однако, исходя из роста данных - 1000 заказов в день, индекс, ускорящий фильтрацию по времени idx_orders_created_at
-- и индекс, который может ускорить агрегацию по товарам idx_orders_products_product_id - все равно разумные предложения для оптимизации.

-- также в запросе используется RECURSIVE CTE для вычисления корневой категории.
-- для ускорения можно в таблице categories хранить root_id, что вообще убирает нужду в рекурсивном CTE, но денормализует таблицу


