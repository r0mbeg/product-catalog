-- 2.1. Получение информации о сумме товаров заказанных под каждого клиента
-- (Наименование клиента, сумма)

-- нужно получить связь клиентов (customers) с товарами (products)
-- для этого с помощью LEFT JOIN (чтобы нулевые суммы тоже были видны)
-- связываем таблицы: customers -> orders -> orders_products -> products

SELECT
  c.name AS customer_name,
  IFNULL(SUM(op.quantity * p.price), 0) AS total_amount
FROM customers c
LEFT JOIN orders o
  ON o.customer_id = c.id
LEFT JOIN orders_products op
  ON op.order_id = o.id
LEFT JOIN products p
  ON p.id = op.product_id
GROUP BY c.id, c.name
ORDER BY customer_name;
