PRAGMA foreign_keys = ON;

INSERT INTO categories (id, name, parent_id) VALUES
  (1, 'Одежда и обувь',  NULL),
  (2, 'Дом',             NULL),
  (3, 'Детские товары',  NULL),
  (4, 'Электроника',     NULL),
  (5, 'Бытовая техника', NULL),
  

  (10, 'Компьютеры',        5),
  (11, 'Стиральные машины', 5),
  (12, 'Телевизоры',        5),
  (13, 'Пылесосы',          5),   
  (14, 'Холодильники',      5),

  (20, 'Ноутбуки',  4),
  (21, 'Моноблоки', 4),
  
  (22, 'однокамерные', 14),
  (23, 'двухкамерные', 14),
  
  (24, '13"', 20),
  (25, '16"', 20);
  
  
INSERT INTO products(id, name, quantity, price, category_id) VALUES
  (1, 'Сиаоми Mini', 15, 50000, 24),
  (2, 'Сиаоми Max', 5, 35000, 25),
	
  (3, 'iMac 24"', 22, 99999, 21),	
  (4, 'iMac 27"', 22, 159999, 21),
	
  (5, 'LG Fridge 50л', 1, 10000, 22),
  (6, 'LG Fridge 150л', 15, 30000, 23);
  
INSERT INTO customers (id, name, address) VALUES
  (1, 'А-Банк',     'Санкт-Петербург, Миллионная ул., 1'),
  (2, 'Z-Банк',     'Санкт-Петербург, ул. Электропультовцев, 15'),
  (3, 'Смирнов ИА', 'Санкт-Петербург, Невский пр., 15');
  
INSERT INTO orders (id, created_at, customer_id) VALUES
  (1, datetime('now','localtime','-8 day'),  2),
  (2, datetime('now','localtime','-13 day'), 3),
  (3, datetime('now','localtime','-21 day'), 2),
  (4, datetime('now','localtime','-34 day'), 1),
  (5, datetime('now','localtime','-55 day'), 3);

INSERT INTO orders_products (order_id, product_id, quantity) VALUES
  -- заказ 1 (8 дней назад)
  (1, 1, 1),  -- Сиаоми Mini
  (1, 3, 1),  -- iMac 24"
  (1, 6, 2),  -- LG Fridge 150л

  -- заказ  2 (13 дней назад)
  (2, 2, 3),  -- Сиаоми Max
  (2, 1, 1),  -- Сиаоми Mini

  -- заказ  3 (21 дней назад)
  (3, 4, 1),  -- iMac 27"
  (3, 2, 1),  -- Сиаоми Max
  (3, 6, 1),  -- LG Fridge 150л

  -- заказ 4 (34 дня назад)
  (4, 5, 2),  -- LG Fridge 50л
  (4, 1, 1),  -- Сиаоми Mini

  -- заказ 5 (55 дней назад)
  (5, 3, 1),  -- iMac 24"
  (5, 6, 1);  -- LG Fridge 150л