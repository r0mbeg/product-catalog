--2.3.1. Написать текст запроса для отчета (view) «Топ-5 самых покупаемых товаров за
-- последний месяц» (по количеству штук в заказах). В отчете должны быть:
-- Наименование товара, Категория 1-го уровня, Общее количество проданных штук.

-- выведем продукты:

SELECT id, name FROM products;

-- теперь свяжем products с таблицей orders_products, 
-- чтобы посмотреть, сколько и каких продуктов было
-- в каждом заказе: свяжем products(id) и orders_products(product_id)
-- LEFT JOIN для получения продуктов, которых нет ни в одном заказе

SELECT 
	op.order_id,
	p.id,
	p.name, 
	op.quantity 
FROM
	products p LEFT JOIN orders_products op
		ON p.id = op.product_id;

-- за последний месяц: нужна таблица orders (поле created_at)
-- добавим её, соединив по orders_products(order_id) и orders(id)
-- + добавим в WHERE отбор по дате (created_at)

SELECT 
	op.order_id,
	p.id,
	p.name,
	o.created_at,
	op.quantity 
FROM
	products p LEFT JOIN orders_products op
		ON p.id = op.product_id
			   LEFT JOIN orders o
		ON op.order_id = o.id
WHERE o.created_at >= datetime('now', 'localtime', '-1 month')

-- теперь посчитаем, сколько каждого товара было куплено:
-- уберём op.order_id и o.created_at, а по op.quantity возьмём сумму
-- также добавим: группировку по p.id
--                сортировку по total_bought от большего (DESC)
--                ограничение результата запроса до 5 (LIMIT 5)

SELECT 
	p.id,
	p.name,
	SUM(op.quantity) AS total_bought
FROM
	products p LEFT JOIN orders_products op
		ON p.id = op.product_id
			   LEFT JOIN orders o
		ON op.order_id = o.id
WHERE o.created_at >= datetime('now', 'localtime', '-1 month')
GROUP BY p.id
ORDER BY total_bought DESC
LIMIT 5;

-- сделаем из этого CTE, добавив категорию (для отображения названия корневой категории):
WITH top5 AS (
SELECT 
	p.id,
	p.name,
	p.category_id,
	SUM(op.quantity) AS total_bought
FROM
-- LEFT JOIN позже можно убрать, так как
-- они превратятся в обычнй JOIN из-за WHERE ...
	products p LEFT JOIN orders_products op
		ON p.id = op.product_id
			   LEFT JOIN orders o
		ON op.order_id = o.id
WHERE o.created_at >= datetime('now', 'localtime', '-1 month')
GROUP BY p.id
ORDER BY total_bought DESC
LIMIT 5
)

-- осталось добавить категорию 1-го уровня для каждого товара
-- для этого в отдельном запросе для каждой категории выясним её корневую категорию
-- для этого заведём рекурсивное CTE, в котором будут поля:
--                                     id категории, id корневой категории: (category_id, root_category_id)
--                                     (которая не является дочерней ни для кого)
--                                      и к которой ведёт id категории
WITH RECURSIVE categories_roots AS (
-- корневые категории: с parent_id = null
  SELECT 
    id,
	id AS root_id -- корневая категория для корневой категории равна самой себе
  FROM 
    categories 
  WHERE parent_id IS NULL

-- объединяем с дочерними в 1 результат
  UNION ALL 
   
-- ищем корневые категории у тех, у которых parent_id <> null
-- с помощью рекурсии
-- т.е. для каждого элемента постепенно добавляем в итоговый WITH дочерние элементы для корней
-- при это LEFT JOIN здесь не нужен - он будет добавлять лишние строки в WITH

  SELECT 
    c.id,
    cr.root_id
		FROM categories c 
		JOIN categories_roots cr
			ON c.parent_id = cr.id
	
)

-- теперь объединим:
-- CTE top5(category_id) и categories_roots(id)
-- и LEFT JOIN с categories(id) для подтягивания названия категории (name):

WITH RECURSIVE categories_roots AS (
  SELECT 
    id,
	id AS root_id
  FROM 
    categories 
  WHERE parent_id IS NULL
  UNION ALL 
  SELECT 
    c.id,
    cr.root_id
		FROM categories c 
		JOIN categories_roots cr
			ON c.parent_id = cr.id
	
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
			   JOIN orders o
		ON op.order_id = o.id
WHERE o.created_at >= datetime('now', 'localtime', '-1 month')
GROUP BY p.id
ORDER BY total_bought DESC
LIMIT 5
)

SELECT 
	top5.product_name AS product_name,
	c.name            AS root_category_name,
	top5.total_bought AS total_bought
FROM top5
-- получаем корневую категорию каждого товара
JOIN categories_roots cr
	ON top5.product_category_id = cr.id
-- получаем название корневой категории
JOIN categories c 
	ON cr.root_id = c.id
ORDER BY total_bought DESC;

-- теперь завернём всё выражение во view:
CREATE VIEW top5_view AS 
WITH RECURSIVE categories_roots AS (
  SELECT 
    id,
	id AS root_id
  FROM 
    categories 
  WHERE parent_id IS NULL
  UNION ALL 
  SELECT 
    c.id,
    cr.root_id
		FROM categories c 
		JOIN categories_roots cr
			ON c.parent_id = cr.id
	
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
			   JOIN orders o
		ON op.order_id = o.id
WHERE o.created_at >= datetime('now', 'localtime', '-1 month')
GROUP BY p.id
ORDER BY total_bought DESC
LIMIT 5
)

SELECT 
	top5.product_name AS product_name,
	c.name            AS root_category_name,
	top5.total_bought AS total_bought
FROM top5
-- получаем корневую категорию каждого товара
JOIN categories_roots cr
	ON top5.product_category_id = cr.id
-- получаем название корневой категории
JOIN categories c 
	ON cr.root_id = c.id
ORDER BY total_bought DESC;

SELECT * FROM top5_view;

