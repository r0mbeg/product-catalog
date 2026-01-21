-- 2.2. Найти количество дочерних элементов первого уровня вложенности
-- для категорий номенклатуры

-- здесь для каждого элемента из таблицы categories
-- нужно посчитать число прямых детей из этой же таблицы
-- то есть для categories c id посчитать число других categories, где parent_id = id
-- с помощью LEFT JOIN можно также считать те категории, у которых 0 детей

SELECT
    parent.name AS parent_name,
    COUNT(child.parent_id)   
FROM
    categories parent
        LEFT JOIN
    categories child
        ON parent.id = child.parent_id
GROUP BY parent_name;
