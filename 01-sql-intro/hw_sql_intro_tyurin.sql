-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Тюрин Данил Андреевич
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: Числовой     тип: INT
--    vacancies.vacancy_name       — категория: Строковый    тип: TEXT
--    vacancies.published_at       — категория: Дата и время тип: TIMESTAMP (without time zone)
--    employers.is_accredited_it   — категория: Логический   тип: BOOLEAN
--    responses.created_at         — категория: Дата и время тип: TIMESTAMP (without time zone)
--
-- 2. Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id (чем особенный:  vacancy_id таблицы vacancy_details является одновременно и первичным ключом, и внешним ключом, который ссылается на первичный ключ vacancy_id в таблице vacancies. Получается, что связь этих таблиц выражается как 1:1, то есть у одной вакансии может быть не больше одного описания, и описание не может быть без вакансии. )
--    responses: response_id
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    vacancy_name не может быть первичным ключом, потому что значение ключа должно быть уникальным
--    и непустым для каждой строки. А название вакансии само по себе не уникальное значение, которое может встречаться очень много раз, и по нему нельзя однозначно определить конкретную вакансию.
--    Запрос для подтверждения числом:

-- запрос:
SELECT vacancy_name, COUNT(*) as cnt
FROM vacancies
GROUP BY vacancy_name
ORDER BY cnt DESC
LIMIT 1;


-- Вывод:
-- Самое часто встречающееся название вакансии - «Стажёр: аналитик данных», оно встречается 6 раз.
-- То есть если бы мы использовали vacancy_name как первичный ключ, его значение повторялось бы
-- шесть раз, что для первичного ключа недопустимо и база данных просто не позволила бы добавить остальные пять вакансий с тем же названием.
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
-- У меня вывелась такая ошибка:
-- "ERROR:  invalid input syntax for type integer: "по договорённости"
-- SQL-состояние: 22P02"
--
-- По данной ошибке мы понимаем, что база данных отклоняет вставку и строка в таблицу не попадает. Это хорошо, потому что указывая тип, мы точно понимаем, что в  salary_from лежат только числа. Также это хорошо, потому что ошибку можно увидеть сразу при вставке датасета, а не через какое-то время в отчетах с неправильными числами и результатами

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
SELECT experience, COUNT(*) as cnt
FROM vacancies
GROUP BY experience;

-- Запрос: employment
SELECT employment, COUNT(*) as cnt
FROM vacancies
GROUP BY employment;

-- Запрос: professional_role
SELECT professional_role, COUNT(*) as cnt
FROM vacancies
GROUP BY professional_role;

-- Вывод:
--  Сколько различных значений в каждой колонке: 
-- experience: 3,  employment: 3,  professional_role: 5
-- 
-- Какие различные значения присутствуют в каждой колонке:
-- experience: От 3 до 6 лет, Нет опыта, От 1 года до 3 лет
-- employment: Частичная занятость, Стажировка, Полная занятость
-- professional_role: Дата-инженер, Разработчик, Продуктовый аналитик, Аналитик данных, Тестировщик
--
-- Признаков проблем с качеством данных я не нашел: значения записаны в едином формате и пропусков тоже нет. 
--
--



-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT v.vacancy_id, v.vacancy_name, v.salary_from, v.published_at
FROM vacancies v
INNER JOIN areas a
ON v.area_id = a.area_id 
WHERE v.employment='Стажировка' AND v.experience = 'Нет опыта' AND a.area_name = 'Москва' AND v.closed_at IS NULL
ORDER BY v.published_at DESC;


-- Запрос 2: топ-10 вакансий по salary_from
SELECT vacancy_name, professional_role, salary_from
FROM vacancies
WHERE salary_from is not null
ORDER BY salary_from DESC
LIMIT 10;

-- Вывод:
-- Первый запрос нашёл 8 открытых стажировок без опыта в Москве. Если убрать условие про Москву,
-- их станет 10, то есть добавятся всего 2 (в Санкт-Петербурге и Екатеринбурге). Значит, почти все
-- открытые стажировки сосредоточены в Москве: в регионах стажировок 10, но 8 из них уже закрыты.
-- То есть, если искать сейчас стажировку, то ориентироваться на Москву, там больше всего вакансий.



-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод:
-- Первый запрос вернул 0, второй 33. Первый запрос с NULL не выдал ошибку, потому что синтаксис правильный. 
-- Но NULL это отсутствие значения, поэтому closed_at = NULL никогда не выполняется и ни одна строчка не подходит. 
-- Это опаснее ошибки: вывод 0 выглядит как нормальный ответ, и можно решить, что открытых вакансий нет. 
-- Значение NULL в колонке closed_at означает, что вакансия еще не закрыта работодателем, то есть кандидат может еще податься на эту вакансию.
-- 
-- База прочитала первое условие во второй паре как:
-- WHERE area_id = 1 OR (area_id = 2 AND experience = 'Нет опыта')
-- То есть база будет выбирать вакансии, которые соответствуют хотя бы одному из двух условий: 
-- Либо любые вакансии из региона 1
-- Либо вакансии из региона 2 И только с опытом "Нет опыта"
-- Это происходит из-за того, что оператор AND имеет более высокий приоритет.
--И чтобы точно ответить на вопрос «вакансии из Москвы или Санкт-Петербурга, но обязательно без опыта», нужно использовать второй запрос, так как в нем правильно поставлены скобки. То есть мы сначала будем выбирать вакансии из Москвы и Санкт-Петербурга и после уже смотреть, чтобы там обязательно можно было податься без опыта.


-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)

SELECT COUNT(*) as vacancies_cnt, COUNT(salary_from) as cnt_salary_from, COUNT(DISTINCT professional_role) as cnt_roles, COUNT(DISTINCT employer_id) as cnt_employers
FROM vacancies;

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT COUNT(*) - COUNT(closed_at) as open_vacancies, COUNT(closed_at) as closed_vacancies, ROUND(((COUNT(*) - COUNT(closed_at))::numeric / COUNT(*)) * 100, 1) as per_open_vacancies
FROM vacancies; 

-- Вывод:
-- COUNT(*) - считает общее количество размещенных вакансий, в нашем случае это 52. 
-- COUNT(salary_from) - считает только те строки в которых нижняя граница зарплат указана - 44, и пропускает те, в которых не указана - 8. 
-- COUNT(DISTINCT professional_role) - считает уникальные значения непустых значений. В нашем случае мы считаем  количество уникальных ролей в вакансиях: 5 направлений и 12 работодателей. 
--
-- Ответ руководителю: "Сейчас активны 33 вакансии из 52 — это 63,5%, то есть почти две трети базы еще открыты для откликов"


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата

SELECT professional_role, COUNT(*) as vacancies_cnt, count(DISTINCT employer_id) AS employers_cnt, ROUND(AVG(salary_from)) as avg_salary_from
FROM vacancies
GROUP BY professional_role
ORDER BY vacancies_cnt DESC;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT professional_role, COUNT(*) as vacancies_cnt, COUNT(DISTINCT employer_id) as employers_cnt, ROUND(AVG(salary_from)) as avg_salary_from
FROM vacancies
WHERE closed_at IS NULL
GROUP BY professional_role
HAVING COUNT(*) >= 5
ORDER BY vacancies_cnt DESC;

-- Вывод:
-- Больше половины рынка занимают две роли: аналитик данных и разработчик. Вместе они составляют 31 вакансию из 52, около 60%. 
-- Соискатель скорее всего сделал бы вывод, что откликаться нужно туда: вакансий больше всего, и он предположит, что из-за этого там и меньше конкуренции. 
-- В этой таблице не хватает двух метрик: конкуренции (сколько откликов приходится на одну вакансию) и шанса на успех (какая доля откликов заканчивается приглашением).
--
-- «Только открытые вакансии» пишется в WHERE, потому что это условие на отдельные строки, а «не менее пяти»  это условие на результат подсчёта внутри группы, 
-- то есть сначала агрегационная функция считает и после уже выполняется условие. Если написать WHERE count(*) >= 5, база выдаст ошибку, что агрегатные функции нельзя использовать в WHERE, потому что в этот момент группы ещё не созданы.
--
-- avg(salary_from) отвечает на вопрос о средней нижней границе зарплаты среди вакансий направления, где она указана. Но данное значение не отвечает на вопрос о зарплате в целом, так как не учитывает: 
--разницу грейдов в таблице (стажер, джун, мидл, сеньор), показывает только нижнюю границу и пропускает вакансии без указанной зарплаты.


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)

SELECT v.vacancy_name, e.employer_name, a.area_name, v.salary_from
FROM vacancies v
INNER JOIN employers e
ON v.employer_id = e.employer_id 
INNER JOIN areas a
ON v.area_id = a.area_id
WHERE v.salary_from IS NOT NULL
ORDER BY v.salary_from DESC
LIMIT 5;

-- Вывод:
-- База данных выведет ошибку, что ссылка неоднозначна. Это означает, что база данных не понимает какой именно ключ одной таблицы мы приравниваем к первичному ключу другой. 
--


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT e.employer_name, count(DISTINCT v.vacancy_id) as vacancies_cnt, count(r.response_id) as responses_cnt
FROM employers e
LEFT JOIN vacancies v
ON e.employer_id = v.employer_id
LEFT JOIN responses r
ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC;


-- Запрос 2: тот же запрос с INNER JOIN
SELECT e.employer_name, count(DISTINCT v.vacancy_id) as vacancies_cnt, count(r.response_id) as responses_cnt
FROM employers e
INNER JOIN vacancies v
ON e.employer_id = v.employer_id
INNER JOIN responses r
ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC;

-- Вывод:
-- Количество вакансий приходится считать через count(DISTINCT ...), потому что после соединения с таблицей откликов каждая вакансия повторяется столько раз, сколько у неё откликов. 

-- Исчезла компания ГринЭнерго. Это произошло из-за того, что у нее одна вакансия и ни одного отклика и INNER JOIN не нашёл для неё пары в таблице откликов. Это содержательная потеря, так как мы изначально и задумывали этот запрос, чтобы найти работодателей, у которых нет интереса. А запрос ее не учел.

--Правило:
-- Когда в результате мне нужно получить только те строчки, которые имеют совпадающие пары в обеих таблицах, которые мы соединяем, нужно использовать INNER JOIN
-- Если в результате мне нужно получить все строчки основной таблицы, включая те, у которых нет связанных записей, я использую LEFT JOIN


-- Доработка с ГринЭнерго
SELECT v.vacancy_id, v.vacancy_name, a.area_name, v.salary_from, v.published_at, v.closed_at, e.is_accredited_it
FROM vacancies v
INNER JOIN employers e
ON v.employer_id = e.employer_id
INNER JOIN areas a
ON v.area_id = a.area_id
WHERE e.employer_name = 'ГринЭнерго';

SELECT e.employer_name, e.is_accredited_it, a.area_name, v.salary_from, v.published_at::date as published, v.closed_at::date as closed, COUNT(r.response_id) as responses_cnt
FROM vacancies v
INNER JOIN employers e
ON v.employer_id = e.employer_id
INNER JOIN areas a
ON v.area_id = a.area_id
LEFT JOIN responses r
ON v.vacancy_id = r.vacancy_id
WHERE v.vacancy_name = 'Стажёр: разработчик'
GROUP BY e.employer_name, e.is_accredited_it, a.area_name, v.salary_from, v.published_at, v.closed_at;

SELECT e.is_accredited_it, COUNT(DISTINCT v.vacancy_id) as vacancies_cnt, COUNT(r.response_id) as responses_cnt,
       ROUND(COUNT(r.response_id)::numeric / nullif(COUNT(DISTINCT v.vacancy_id), 0), 1) as responses_per_vacancy
FROM vacancies v
INNER JOIN employers e
ON v.employer_id = e.employer_id
LEFT JOIN responses r
ON v.vacancy_id = r.vacancy_id
GROUP BY e.is_accredited_it;

-- Чтобы более точно ответить на вопрос про компанию "ГринЭнерго" я решил реализовать три sql запроса, которые показали более полную картину:
-- 1. Первым SQL запросом я проверил какой тип вакансии.
-- 2. Дальше я начал проверять похожие вакансии у других компаний
-- 3. Проверил один из параметров, который отличался у компаний - аккредитация

-- Что в итоге получилось:
-- Это стажировка «Стажёр: разработчик» в Казани, она была открыта почти месяц с 6 апреля по 4 мая и сейчас уже закрыта,
-- то есть время на отклики было. Интерес к самой позиции есть: такая же стажировка у УралСофт в то же время
-- собрала 27 откликов. Город тоже не является причиной: вакансии Казань Диджитал в Казани собрали 13–21 отклик.
-- Отличия у ГринЭнерго другие: компания не IT-аккредитована, и зарплата в вакансии не указана.
-- Неаккредитованные компании в среднем получают 4,8 отклика на вакансию против 14,3 у аккредитованных,
-- а у второй такой же стажировки неаккредитованной компании СибирьТелеком тоже 0 откликов, хотя зарплата там указана.
-- 
-- Что можно предложить на основе данных: указать зарплату и сделать её чуть выше, чем у аккредитованных компаний, потому что у неаккредитованных откликов заметно меньше: 4,8 на вакансию против 14,3. При одинаковой зарплате 50 тысяч УралСофт получил 27 откликов, а СибирьТелеком — 0.

-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)

SELECT date_trunc('month', r.created_at)::date as month, COUNT(*) as responses_cnt,
       SUM(CASE WHEN r.status = 'invited' THEN 1 ELSE 0 END) as invited_cnt,
       ROUND(100.0 * sum(CASE WHEN r.status = 'invited' THEN 1 ELSE 0 END) / nullif(count(*), 0), 1) as conversion_pct
FROM responses r
GROUP BY 1
ORDER BY 1;

-- Как проверял последнюю дату
SELECT max(created_at) 
FROM responses;

-- Как проверял статусы откликов в августе
SELECT status, COUNT(*) as cnt
FROM responses
WHERE created_at >= '2026-08-01'
GROUP BY status
ORDER BY cnt DESC;

-- Как проверял распределение приглашений по компаниям в июне
SELECT e.employer_name, COUNT(*) as invited_cnt
FROM responses r
INNER JOIN vacancies v
ON r.vacancy_id = v.vacancy_id
INNER JOIN employers e
ON v.employer_id = e.employer_id
WHERE r.status = 'invited' AND date_trunc('month', r.created_at) = '2026-06-01'
GROUP BY e.employer_name;

-- Вывод:
-- По данным можно увидеть, что легче всего получить приглашение можно было в июне, там конверсия была максимальная - 19,5 %
--
-- Июню вроде можно доверять, потому что там много откликов - 118, и одно приглашение почти не влияет на конверсию. Но большую часть приглашений дали всего две компании, и данные у нас только за один год, поэтому делать выводы только на основе этих данных я бы не стал.
--
-- Последний месяц в таблице - Август. И его лучше исключить из выводов, так как он неполный: последний отклик записан в базе 15 августа, то есть данные обрываются на середине месяца. Также 39 % откликов еще не успели обработать: 16 из 41 до сих пор в статусе new или viewed. Пока по этим данным еще нельзя считать конверсию. 

-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
SELECT v.professional_role, COUNT(DISTINCT v.vacancy_id) as vacancies_cnt, COUNT(r.response_id) as responses_cnt,
       SUM(CASE WHEN r.status = 'invited' THEN 1 ELSE 0 END) as invited_cnt,
       ROUND(count(r.response_id)::numeric / nullif(count(DISTINCT v.vacancy_id), 0), 1) as responses_per_vacancy,
       ROUND(100.0 * sum(CASE WHEN r.status = 'invited' THEN 1 ELSE 0 END) / nullif(count(r.response_id), 0), 1) as conversion_pct
FROM vacancies v
LEFT JOIN responses r
ON v.vacancy_id = r.vacancy_id
GROUP BY v.professional_role
ORDER BY vacancies_cnt DESC;

-- Запрос связанный с  «Логистик Плюс» 
SELECT e.employer_name, COUNT(*) as invited_cnt
FROM responses r
INNER JOIN vacancies v
ON r.vacancy_id = v.vacancy_id
INNER JOIN employers e
ON v.employer_id = e.employer_id
WHERE r.status = 'invited' AND v.professional_role = 'Тестировщик'
GROUP BY e.employer_name;

-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
-- Нет, не совпадает. Больше всего вакансий у аналитиков данных - 16, но у них достаточно низкая конверсия 12,1%. Самая высокая конверсия у тестировщиков - 35,9%, но вакансий у них намного меньше, чем у аналитики - всего 7.
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- Учитывая эти данные, я бы выбрал тестировщика. В этом направлении самая высокая конверсия: каждый третий отклик заканчивается приглашением + там одна из самых маленьких конкуренций: в среднем 5,6 отклика на вакансию
-- 3. Оговорка к выводу:
-- Но стоит сказать, что направление тестировки слишком мало данных. В таблице всего 39 откликов и 14 приглашений. Также меня смущает, что половина приглашений дала одна компания "Логистик Плюс". Поэтому такая высокая конверсия может быть аномалией, что вдруг одной компании пригодились тестировщики и из-за этого конверсия резко выросла.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
-- SELECT v.professional_role,
-- count(*) AS vacancies,
-- sum(v.salary_from) AS total_salary,
-- count(r.response_id) / count(*) AS responses_per_vacancy
-- FROM vacancies v
-- JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = NULL
-- GROUP BY 1;
--
-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL. Ошибка как в задании Б3.
-- 2. JOIN. Он выбрасывает открытые вакансии без откликов, из-за этого вакансий получается меньше, а откликов на вакансию больше, чем на самом деле
-- 3. count(*) AS vacancies. Ошибка состоит в том, что после JOIN каждая вакансия повторяется столько раз, сколько у нее откликов и получается, что count(*) считает отклики, а не вакансии
-- 4. sum(v.salary_from). Опять из-за JOIN строк становится больше и  зарплата каждой вакансии складывается столько раз, сколько у неё откликов.
-- 5. count(r.response_id) / count(*). Целочисленное деление, и оба count считают одни и те же строки, поэтому везде получается 1.
-- Исправленный запрос:
SELECT v.professional_role, COUNT(DISTINCT v.vacancy_id) as vacancies_cnt, COUNT(r.response_id) as responses_cnt,
       ROUND(COUNT(r.response_id)::numeric / nullif(COUNT(DISTINCT v.vacancy_id), 0), 1) as responses_per_vacancy
FROM vacancies v
LEFT JOIN responses r
ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY v.professional_role
ORDER BY responses_per_vacancy DESC;

-- Так как мы в этой лекции не изучали подзапросы и with, я на всякий случай решил не использовать их. Решил отдельно сделать второй запрос для средней зарплаты.
SELECT professional_role, ROUND(AVG(salary_from)) as avg_salary_from
FROM vacancies
WHERE closed_at IS NULL
GROUP BY professional_role;
-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. На лекции в квизе 5 есть правило: сравнение с NULL никогда не истинно - пустоту проверяют оператором IS NULL
-- 2. LEFT JOIN сохраняет все строки левой таблицы, поэтому, если нужны объекты без пары  , используют LEFT JOIN, а вакансии после соединения с откликами считают через COUNT(DISTINCT )