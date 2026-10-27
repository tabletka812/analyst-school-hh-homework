-- ============================================================
-- Домашнее задание к лекции Продвинутый SQ
-- Школа Аналитиков · учебная база hh_school
-- Автор: Тюрин Данил Андреевич
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Качество и подготовка данных
-- ============================================================

-- Задание 1 


-- Решил начать с проверки пропусков в таблице calls
SELECT
    COUNT(*) - COUNT(call_id) AS null_values_in_call_id,
    COUNT(*) - COUNT(response_id) AS null_values_in_response_id,
    COUNT(*) - COUNT(employer_id) AS null_values_in_employer_id,
    COUNT(*) - COUNT(applicant_id) AS null_values_in_applicant_id,
    COUNT(*) - COUNT(vacancy_id) AS null_values_in_vacancy_id,
    COUNT(*) - COUNT(caller_role) AS null_values_in_caller_role,
    COUNT(*) - COUNT(status) AS null_values_in_status,
    COUNT(*) - COUNT(call_at) AS null_values_in_call_at,
    COUNT(*) - COUNT(call_duration) AS null_values_in_call_duration,
    COUNT(*) FILTER (WHERE CARDINALITY(call_tags) = 0) AS empty_call_tags
FROM calls;
-- Что получил: пропуски оказались в response_id: 8, call_duration: 70. В остальных колонках пропусков не оказалось.
-- Там где обнаружил пропуски, пытаюсь выяснить откуда они взялись и что с ними делать.



-- Пропуски в call_duration
SELECT
    status,
    COUNT(*) AS calls_cnt,
    COUNT(*) - COUNT(call_duration) AS null_duration_cnt
FROM calls
GROUP BY status;
-- 70 пустых длительностей приходятся на неуспешные звонки - это допустимый сценарий. То есть работодатель просто не дозвонился, длительности не должно быть. У успешных звонков длительность заполнена везде.
-- Ничего не исключаю.


-- отдельно проверю тег звонка где произошла ошибка и в status было "error"
SELECT
    call_id,
    response_id,
    caller_role,
    status,
    call_duration,
    call_at,
    call_tags
FROM calls
WHERE status = 'error';
-- Теги согласуются со статусом: {voice,technical_error,outbound,interview}. 
-- Работодатель попытался дозвониться до кандидата, но во время звонка произошла ошибка, поэтому это можно считать как коммуникацию, только неуспешную. 



-- Проверяю response_id
SELECT
    call_id,
    caller_role,
    status,
    call_duration,
    call_at,
    employer_id,
    vacancy_id
FROM calls
WHERE response_id IS NULL
ORDER BY call_id;
-- Интересно, что все 8 звонков от работодателя, а employer_id и vacancy_id у них заполнены.
-- Получается что звонок был и понятно по какой вакансии. Можно попробовать восстановить отклики через запрос



-- Запрос который поможет восстановить отклики. Делаем это через сообщение того же кандидата по той же вакансии
SELECT
    c.call_id,
    c.applicant_id,
    c.vacancy_id,
    m.response_id AS response_id_from_messages
FROM calls AS c
LEFT JOIN messages AS m
    ON c.applicant_id = m.applicant_id
    AND c.vacancy_id = m.vacancy_id
WHERE c.response_id IS NULL
GROUP BY
    c.call_id,
    c.applicant_id,
    c.vacancy_id,
    m.response_id
ORDER BY c.call_id;
-- Получилось 8 строк на 8 звонков, значит ни у одного звонка не нашлось двух разных откликов.
-- Отклик нашёлся у 7 звонков из 8. У звонка 700246 пусто: у этого кандидата по вакансии 1023 нет сообщений.


-- Попытаемся восстановить звонок, который не получилось сделать с помощью прошлого запроса. Для этого использую запрос, который ищет отклик в других звонках того же кандидата по той же вакансии
SELECT
    c.call_id,
    c2.response_id AS response_id_from_calls
FROM calls AS c
LEFT JOIN calls AS c2
    ON c.applicant_id = c2.applicant_id
    AND c.vacancy_id = c2.vacancy_id
    AND c2.response_id IS NOT NULL
WHERE c.call_id = 700246;
-- отклик нашёлся. Теперь отклик найден для всех 8 звонков


-- После этого всего, я решил вывести информацию с этими 8 восстановленными звонками.
SELECT
    c.call_id,
    c.status,
    c.call_duration,
    c.call_at,
    c.call_tags,
    r.response_id,
    r.status AS response_status,
    r.created_at AS response_created_at
FROM calls AS c
JOIN responses AS r
    ON c.applicant_id = r.resume_id
    AND c.vacancy_id = r.vacancy_id
WHERE c.response_id IS NULL
ORDER BY c.call_id;
-- И я обнаружил интересную закономерность: у всех этих 8 восстановленных мной откликов (700244, 700245, 700246, 700247, 700248, 700249, 700250, 700251), звонки были сделаны раньше этого отклика. 

-- Вывод, который я сделал: 
-- Звонки без response_id были сделаны раньше этого отклика, значит привязать их к отклику нельзя.
-- У меня возникает предположение, что скорее всего работодатель сам нашел кандидата и соответственно позвонил. 
-- При дальнейших расчетах, допустим при расчете бизнес вопрос о том как работодатели обрабатывают отклики, эти данные не подходят. Поэтому мы их исключаем.




-- Проверка пропусков в таблице messages
SELECT
    COUNT(*) - COUNT(message_id) AS null_values_in_message_id,
    COUNT(*) - COUNT(response_id) AS null_values_in_response_id,
    COUNT(*) - COUNT(employer_id) AS null_values_in_employer_id,
    COUNT(*) - COUNT(applicant_id) AS null_values_in_applicant_id,
    COUNT(*) - COUNT(vacancy_id) AS null_values_in_vacancy_id,
    COUNT(*) - COUNT(sender_role) AS null_values_in_sender_role,
    COUNT(*) - COUNT(sent_at) AS null_values_in_sent_at,
    COUNT(*) - COUNT(message_text) AS null_values_in_message_text,
    COUNT(*) FILTER (WHERE TRIM(message_text) = '') AS empty_message_text,
    COUNT(*) - COUNT(message_meta) AS null_values_in_message_meta
FROM messages;
-- Во всех колонках 0, пустых текстов сообщений тоже нет
-- Пропусков в messages нет, на этом этапе ничего не исключаю

-- Проверяю, что внутри JSON нет пропусков или ненужного поля
SELECT
    COUNT(*) FILTER (WHERE NOT message_meta ? 'channel') AS no_channel_key,
    COUNT(*) FILTER (WHERE NOT message_meta ? 'is_read') AS no_is_read_key,
    COUNT(*) FILTER (WHERE NOT message_meta ? 'attachments') AS no_attachments_key,
    COUNT(*) FILTER (WHERE message_meta ->> 'channel' IS NULL) AS null_channel,
    COUNT(*) FILTER (WHERE message_meta ->> 'is_read' IS NULL) AS null_is_read,
    COUNT(*) FILTER (WHERE message_meta ->> 'attachments' IS NULL) AS null_attachments
FROM messages;
-- Во всех колонках 0. Все три ключа есть в каждом сообщении, пустых значений нет. Пропусков внутри message_meta тоже нет


-- Проверка на то, что звонки раньше отклика
SELECT
    COUNT(*) AS illogical_calls
FROM calls AS c
JOIN responses AS r
ON c.response_id = r.response_id
WHERE c.call_at < r.created_at;
-- Вывелось 0. Все звонки с response_id были после отклика, значит нет никаких проблем.

-- Проверка на то, что сообщения раньше отклика
SELECT
    COUNT(*) AS illogical_messages
FROM messages AS m
JOIN responses AS r
ON m.response_id = r.response_id
WHERE m.sent_at < r.created_at;
-- Вывелось 0. Значит все сообщения были отправлены после отклика, проблем нет 

-- Проверяю на несовпадение идентификаторов события и отклика
SELECT
    SUM(CASE WHEN c.vacancy_id <> r.vacancy_id THEN 1 ELSE 0 END) AS wrong_vacancy,
    SUM(CASE WHEN c.applicant_id <> r.resume_id THEN 1 ELSE 0 END) AS wrong_applicant,
    SUM(CASE WHEN c.employer_id <> v.employer_id THEN 1 ELSE 0 END) AS employer_wrong
FROM calls AS c
JOIN responses AS r
ON c.response_id = r.response_id
JOIN vacancies AS v
ON r.vacancy_id = v.vacancy_id;
-- Вывелись везде 0. У каждого звонка вакансия, кандидат и работодатель такие же, как у его отклика


-- Проверяю несовпадение идентификаторов сообщения и отклика
SELECT
    SUM(CASE WHEN m.vacancy_id <> r.vacancy_id THEN 1 ELSE 0 END) AS wrong_vacancy,
    SUM(CASE WHEN m.applicant_id <> r.resume_id THEN 1 ELSE 0 END) AS wrong_applicant,
    SUM(CASE WHEN m.employer_id <> v.employer_id THEN 1 ELSE 0 END) AS wrong_employer
FROM messages AS m
JOIN responses AS r
ON m.response_id = r.response_id
JOIN vacancies AS v
ON r.vacancy_id = v.vacancy_id;
-- Результат во всех столбцах 0. 
-- У каждого сообщения вакансия, кандидат и работодатель тоже совпадают с откликом. Получается, что мы можем корректно связать все события с response_id с откликом и работодателем.


-- Дальше я решил посмотреть какие теги встречаются при каждом статусе звонка, чтобы найти противоречия 
SELECT
    c.status,
    t.tag,
    COUNT(*) AS calls_cnt
FROM calls AS c
CROSS JOIN UNNEST(c.call_tags) AS t(tag)
GROUP BY c.status, t.tag
ORDER BY c.status, t.tag;

-- По таблице видно, что тег connected есть у всех 181 успешного звонка и больше нигде; тег no_answer - у всех 69
-- неуспешных и больше нигде; тег technical_error - только у звонка со статусом error.
-- Из этого можно сказать, что  у каждого звонка ровно один тег результата, и он совпадает со статусом. Также у каждого звонка ровно одно направление либо inbound, либо outbound


-- Проверяю, совпадает ли кто звонил с направлением звонка в тегах
SELECT
    c.caller_role,
    t.tag,
    COUNT(*) AS calls_cnt
FROM calls AS c
CROSS JOIN UNNEST(c.call_tags) AS t(tag)
WHERE t.tag IN ('inbound', 'outbound')
GROUP BY c.caller_role, t.tag
ORDER BY c.caller_role, t.tag;
-- Всё правильно: кандидат звонил 84 раза и помечено как "inbound", а работодатель 167 раз и помечено как "outbound". 
-- 84 + 167 = 251, это все звонки. Ничего друг другу не противоречит. 

-- На этом моменте я заметил, что часть проверок уже гарантирована схемой таблиц и некоторые проверки, которые были написаны выше можно было и не делать. Я не стал их удалять, просто в дальнейшем буду более внимательным и не буду делать ненужных проверок дальше 


-- Проверяю значения внутри message_meta: нет ли опечаток и неожиданных вариантов.
SELECT
    message_meta ->> 'channel' AS channel,
    COUNT(*) AS messages_cnt
FROM messages
GROUP BY message_meta ->> 'channel';
-- web 1866 | mobile_app 996
-- Без опечаток и разного регистра

SELECT
    message_meta ->> 'is_read' AS is_read,
    COUNT(*) AS messages_cnt
FROM messages
GROUP BY message_meta ->> 'is_read';
-- true 2619 | false 243
-- Только true и false, других значений нет



-- Проверяю диапазоны дат, нет ли странных значений
SELECT
    MIN(call_at) AS first_call,
    MAX(call_at) AS last_call
FROM calls;
-- 2026-01-19 09:50 | 2026-09-05 09:00

SELECT
    MIN(sent_at) AS first_message,
    MAX(sent_at) AS last_message
FROM messages;
-- 2026-01-15 10:10 | 2026-09-03 23:04
-- Даты выглядят нормально, без каких-либо аномальных значений


-- Проверяю события на дубли, чтобы в данных не было одного и того же события, записанного несколько раз
SELECT
    response_id,
    call_at,
    caller_role,
    COUNT(*) AS calls_cnt
FROM calls
GROUP BY
    response_id,
    call_at,
    caller_role
HAVING COUNT(*) > 1;

SELECT
    response_id,
    sent_at,
    sender_role,
    COUNT(*) AS messages_cnt
FROM messages
GROUP BY
    response_id,
    sent_at,
    sender_role
HAVING COUNT(*) > 1;
-- Оба запроса вернули 0 строк, дублей нет



-- Исследование call_duration успешных звонков
-- Условия основанные на прошлых запросах: беру только успешные звонки с response_id: 3 успешных звонка из исключённых выше в расчёт не попадают, поэтому звонков 178, а не 181


SELECT
    COUNT(*) AS calls_cnt,
    MIN(call_duration) AS min_duration,
    MAX(call_duration) AS max_duration,
    ROUND(AVG(call_duration), 1) AS avg_duration,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY call_duration) AS median_duration,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99_duration
FROM calls
WHERE status = 'successful' AND response_id IS NOT NULL;
-- 178 | 51 | 899 | 470.6 | 449.5 | 890.46

-- Средняя длительность без звонков выше 99 перцентиля
WITH percentile_table AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS percen_duration
    FROM calls
    WHERE status = 'successful' AND response_id IS NOT NULL
)
SELECT
    ROUND(AVG(c.call_duration), 1) AS avg_duration_without_p99
FROM calls AS c
CROSS JOIN percentile_table AS p
WHERE c.status = 'successful' AND c.response_id IS NOT NULL AND c.call_duration <= p.percen_duration;
-- 465.8

-- Смотрю, какие именно звонки выше 99 перцентиля
WITH percentile_table AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99_duration
    FROM calls
    WHERE status = 'successful' AND response_id IS NOT NULL
)
SELECT
    c.call_id,
    c.call_duration,
    c.call_tags
FROM calls AS c
CROSS JOIN percentile_table AS p
WHERE c.status = 'successful' AND c.response_id IS NOT NULL AND c.call_duration > p.p99_duration
ORDER BY c.call_id;
-- 700159 | 892 | {voice,connected,inbound,screening}
-- 700199 | 899 | {voice,connected,outbound,details}
-- Выше 99 перцентиля всего два звонка


-- Итоговый вывод по заданию 1:
-- 1. Звонки без response_id: нашел 8 штук (700244, 700245, 700246, 700247, 700248, 700249, 700250, 700251). Все были сделаны на 1–5 дней раньше отклика того же
--    кандидата, значит к обработке отклика не относятся. Это влияет на на сам факт коммуникации, поэтому исключаю 
-- 2. Пропуски в call_duration 70 строк: 69 неуспешных + 1 с ошибкой . У этих звонков
--    длительности и не должно быть. Все нормально, ничего с этим не делаю 
-- 3. Звонок со статусом error: 1 случай (700163). Теги это подтверждают, считаю его как неуспешной попыткой связаться.

-- Все остальные мои проверки времени, идентификаторов, тегов, JSON, дат и дублей не обнаружили проблем.
--
-- Длительность успешных звонков 178 штук: среднее 470.6 сек, медиана 449.5 сек, 99 перцентиль 890.5 сек,
-- выше 99 перцентиля — 2 звонка (700159, 700199), среднее без них 465.8 сек.
-- Звонки, которые выше 99 перцентиля я считаю нормальными: это звонки около 15 минут, что вполне
-- реально, без них среднее меняется всего на 5 секунд. Поэтому не удаляю. Как типичную длительность буду брать медиану.

-- ============================================================
-- Блок Б. История коммуникаций
-- ============================================================

-- Задание 2

WITH  response_first_week as (
    SELECT
        response_id,
        created_at AS week_start,
        created_at + INTERVAL '7 day' AS week_end
    FROM responses
),
employer_messages_7d AS (
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_first_week AS rw
    ON m.response_id = rw.response_id
    WHERE m.sender_role = 'employer' AND m.sent_at >= rw.week_start AND m.sent_at < rw.week_end
),
employer_calls_7d AS (
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_first_week AS rw
    ON c.response_id = rw.response_id
    WHERE c.caller_role = 'employer' AND c.call_at >= rw.week_start AND c.call_at < rw.week_end
),
employer_events_7d AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages_7d
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls_7d
)
SELECT
    COUNT(*) AS events_cnt,
    COUNT(DISTINCT response_id) AS responses_with_events_cnt,
    COUNT(*) FILTER (WHERE event_type = 'call') AS calls_cnt,
    COUNT(*) FILTER (WHERE event_type = 'message') AS messages_cnt
FROM employer_events_7d;
-- Событий: 1096, откликов с коммуникацией: 382, звонков: 108, сообщений: 988.
-- По данным можно увидеть, что сообщений почти в 9 раз больше, чем звонков. Вывод можно сделать такой: в первую неделю работодатели в основном пишут




-- Задание 3

WITH response_first_week AS (
    SELECT
        response_id,
        created_at AS week_start,
        created_at + INTERVAL '7 day' AS week_end
    FROM responses
),
employer_messages_7d AS (
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_first_week AS rw
    ON m.response_id = rw.response_id
    WHERE m.sender_role = 'employer' AND m.sent_at >= rw.week_start AND m.sent_at < rw.week_end
),
employer_calls_7d AS (
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_first_week AS rw
    ON c.response_id = rw.response_id
    WHERE c.caller_role = 'employer' AND c.call_at >= rw.week_start AND c.call_at < rw.week_end
),
employer_events_7d AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages_7d
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls_7d
),
events_timeline AS (
    -- Шаг 1. Одна строка = одно событие: окна только добавляют колонки, гранулярность не меняется.
    -- Если время одинаковое, порядок задаю через event_type, а потом event_id
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS event_num,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS prev_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS events_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM employer_events_7d
),
first_events AS (
    SELECT
        response_id,
        event_at AS first_event_at,
        event_type AS first_event_type,
        last_event_type
    FROM events_timeline
    WHERE event_num = 1
),
second_events AS (
    -- одна строка = второе событие отклика (есть не у всех)
    SELECT
        response_id,
        event_type AS second_event_type
    FROM events_timeline
    WHERE event_num = 2
),
event_counts AS (
  
    SELECT
        response_id,
        COUNT(*) AS events_cnt,
        SUM(CASE WHEN event_type = 'call' THEN 1 ELSE 0 END) AS calls_cnt,
        SUM(CASE WHEN event_type = 'message' THEN 1 ELSE 0 END) AS messages_cnt,
        MAX(event_at - prev_event_at) AS max_gap
    FROM events_timeline
    GROUP BY response_id
),
res_summary AS (
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        COALESCE(ec.events_cnt, 0) AS events_cnt,
        COALESCE(ec.calls_cnt, 0) AS calls_cnt,
        COALESCE(ec.messages_cnt, 0) AS messages_cnt,
        fe.first_event_at,
        fe.first_event_type,
        se.second_event_type,
        fe.last_event_type,
        ROUND(EXTRACT(EPOCH FROM fe.first_event_at - r.created_at) / 3600, 1) AS hours_to_first_event,
        ROUND(EXTRACT(EPOCH FROM ec.max_gap) / 3600, 1) AS max_gap_hours
    FROM responses AS r
    JOIN vacancies AS v
     ON r.vacancy_id = v.vacancy_id
    LEFT JOIN event_counts AS ec
    ON r.response_id = ec.response_id
    LEFT JOIN first_events AS fe
     ON r.response_id = fe.response_id
    LEFT JOIN second_events AS se
     ON r.response_id = se.response_id
)


SELECT
    COUNT(*) AS rows_cnt,
    COUNT(*) FILTER (WHERE events_cnt > 0) AS res_with_events,
    COUNT(*) FILTER (WHERE events_cnt = 0) AS res_without_events,
    COUNT(*) FILTER (WHERE first_event_type = 'message') AS first_is_message,
    COUNT(*) FILTER (WHERE first_event_type = 'call') AS first_is_call
FROM res_summary;
-- 628 | 382 | 246 | 314 | 68
-- Больше трети откликов работодатели не обработали в первую неделю никак. Также , если работодатель выходил на связь то почти всегда начинал с сообщения: 314 сообщений и всего 68 звонков

-- ============================================================
-- Блок В. Сравнение работодателей
-- ============================================================

-- Задание 4

WITH response_first_week AS (
    SELECT
        response_id,
        created_at AS week_start,
        created_at + INTERVAL '7 day' AS week_end
    FROM responses
),
employer_messages_7d AS (
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_first_week AS rw
    ON m.response_id = rw.response_id
    WHERE m.sender_role = 'employer' AND m.sent_at >= rw.week_start AND m.sent_at < rw.week_end
),
employer_calls_7d AS (
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_first_week AS rw
     ON c.response_id = rw.response_id
    WHERE c.caller_role = 'employer' AND c.call_at >= rw.week_start AND c.call_at < rw.week_end
),
employer_events_7d AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages_7d
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls_7d
),
events_timeline AS (
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS event_num,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS prev_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS events_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        -- расширяю рамку до конца отклика, иначе LAST_VALUE вернёт текущее событие
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM employer_events_7d
),
first_events AS (
    SELECT
        response_id,
        event_at AS first_event_at,
        event_type AS first_event_type,
        last_event_type
    FROM events_timeline
    WHERE event_num = 1
),
second_events AS (
    SELECT
        response_id,
        event_type AS second_event_type
    FROM events_timeline
    WHERE event_num = 2
),
event_counts AS (
    SELECT
        response_id,
        COUNT(*) AS events_cnt,
        SUM(CASE WHEN event_type = 'call' THEN 1 ELSE 0 END) AS calls_cnt,
        SUM(CASE WHEN event_type = 'message' THEN 1 ELSE 0 END) AS messages_cnt,
        MAX(event_at - prev_event_at) AS max_gap
    FROM events_timeline
    GROUP BY response_id
),
res_summary AS (
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        COALESCE(ec.events_cnt, 0) AS events_cnt,
        COALESCE(ec.calls_cnt, 0) AS calls_cnt,
        COALESCE(ec.messages_cnt, 0) AS messages_cnt,
        fe.first_event_at,
        fe.first_event_type,
        se.second_event_type,
        fe.last_event_type,
        ROUND(EXTRACT(EPOCH FROM fe.first_event_at - r.created_at) / 3600, 1) AS hours_to_first_event,
        ROUND(EXTRACT(EPOCH FROM ec.max_gap) / 3600, 1) AS max_gap_hours
    FROM responses AS r
    JOIN vacancies AS v
        ON r.vacancy_id = v.vacancy_id
    LEFT JOIN event_counts AS ec
        ON r.response_id = ec.response_id
    LEFT JOIN first_events AS fe
        ON r.response_id = fe.response_id
    LEFT JOIN second_events AS se
        ON r.response_id = se.response_id
),
employer_stats AS (
    SELECT
        professional_role,
        employer_id,
        COUNT(*) AS responses_cnt,
        COUNT(*) FILTER (WHERE events_cnt > 0) AS responses_with_events_cnt,
        100.0 * COUNT(*) FILTER (WHERE events_cnt > 0) / COUNT(*) AS processed_share,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_event) AS median_hours_to_first,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours_to_first_event) AS p90_hours_to_first,
        ROUND(100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*), 1) AS invite_conversion
    FROM res_summary
    GROUP BY
        professional_role,
        employer_id
    HAVING COUNT(*) >= 8
),
employer_rating AS (
    SELECT
        professional_role,
        employer_id,
        responses_cnt,
        responses_with_events_cnt,
        processed_share,
        median_hours_to_first,
        p90_hours_to_first,
        invite_conversion,
        DENSE_RANK() OVER (
            PARTITION BY professional_role
            ORDER BY processed_share DESC, median_hours_to_first
        ) AS employer_place
    FROM employer_stats
)
SELECT
    professional_role,
    employer_place,
    employer_id,
    responses_cnt,
    responses_with_events_cnt,
    ROUND(processed_share, 1) AS processed_share,
    ROUND(median_hours_to_first::numeric, 1) AS median_hours_to_first,
    ROUND(p90_hours_to_first::numeric, 1) AS p90_hours_to_first,
    invite_conversion
FROM employer_rating
WHERE employer_place <= 2
ORDER BY professional_role, employer_place, employer_id;
-- Аналитик данных | 1 | 109
-- Аналитик данных | 2 | 103
-- Дата-инженер | 1 | 106
-- Дата-инженер | 2 | 101
-- Продуктовый аналитик | 1 | 103
-- Продуктовый аналитик | 2 | 102
-- Разработчик | 1 | 112
-- Разработчик | 2 | 104
-- Тестировщик | 1 | 107
-- Тестировщик | 2 | 108
-- Лучше всех обрабатывают отклики работодатель 109 у аналитиков данных 89.5% и работодатель 107 у тестировщиков 88.2%


-- Задание 5

WITH messages_7d AS (
    SELECT
        m.message_id,
        m.response_id,
        m.employer_id,
        m.sender_role,
        m.sent_at
    FROM messages AS m
    JOIN responses AS r
    ON m.response_id = r.response_id
    WHERE m.sent_at >= r.created_at AND m.sent_at < r.created_at + INTERVAL '7 day'
),
messages_with_prev AS (
    SELECT
        message_id,
        response_id,
        employer_id,
        sender_role,
        sent_at,
        LAG(sender_role) OVER ( PARTITION BY response_id ORDER BY sent_at, message_id
        ) AS prev_sender_role,
        LAG(sent_at) OVER (
            PARTITION BY response_id ORDER BY sent_at, message_id
        ) AS prev_sent_at
    FROM messages_7d
),
employer_replies AS (
    SELECT
        employer_id,
        message_id,
        EXTRACT(EPOCH FROM sent_at - prev_sent_at) / 3600 AS reply_hours
    FROM messages_with_prev
    WHERE sender_role = 'employer' AND prev_sender_role = 'applicant'
)
SELECT
    employer_id,
    COUNT(*) AS replies_cnt,
    ROUND(AVG(reply_hours), 1) AS avg_reply_hours,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reply_hours))::numeric, 1) AS median_reply_hours,
    ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY reply_hours))::numeric, 1) AS p90_reply_hours
FROM employer_replies
GROUP BY employer_id
ORDER BY median_reply_hours;
-- Всего найдено ответов: 749.=
-- Минимальная медиана у работодателя 107: 3.9 часа
-- Медианы у всех работодателей от 3.9 до 4.9 часа, а среднее несколько выше медианы 6–9 часов:
-- обычно работодатели отвечают за несколько часов, но иногда ответ затягивается почти на сутки: 90 перцентиль около 19 часов 


-- ============================================================
-- БЛОК Г. Сложные типы данных
-- ============================================================

-- Задание 6.1. Теги звонков
WITH employer_calls_7d AS (
    SELECT
        c.call_id,
        c.status,
        c.call_tags
    FROM calls AS c
    JOIN responses AS r
    ON c.response_id = r.response_id
    WHERE c.caller_role = 'employer' AND c.call_at >= r.created_at
        AND c.call_at < r.created_at + INTERVAL '7 day'
),
call_tags_rows AS (
    SELECT
        ec.call_id,
        ec.status,
        t.tag
    FROM employer_calls_7d AS ec
    CROSS JOIN UNNEST(ec.call_tags) AS t(tag)
),
calls_check AS (
    SELECT
        call_id,
        status,
        COUNT(*) AS tags_cnt,
        COUNT(*) FILTER (WHERE tag = 'connected') AS connected_cnt,
        COUNT(*) FILTER (WHERE tag = 'no_answer') AS no_answer_cnt,
        COUNT(*) FILTER (WHERE tag = 'technical_error') AS tech_error_cnt
    FROM call_tags_rows
    GROUP BY call_id, status
),
valid_calls AS (
    SELECT
        call_id,
        tags_cnt
    FROM calls_check
    WHERE (status = 'successful' AND connected_cnt = 1 AND no_answer_cnt = 0 AND tech_error_cnt = 0)
        OR (status = 'unsuccessful' AND no_answer_cnt = 1 AND connected_cnt = 0 AND tech_error_cnt = 0)
        OR (status = 'error' AND tech_error_cnt = 1 AND connected_cnt = 0 AND no_answer_cnt = 0)
),
business_tags AS (
    SELECT
        t.call_id,
        t.tag
    FROM call_tags_rows AS t
    JOIN valid_calls AS vc
    ON t.call_id = vc.call_id
    WHERE t.tag IN ('screening', 'interview', 'follow_up', 'details')
)
SELECT
    tag,
    COUNT(*) AS calls_cnt,
    (SELECT COUNT(*) FROM calls_check) - (SELECT COUNT(*) FROM valid_calls) AS invalid_calls,
    (SELECT COUNT(DISTINCT call_id) FROM business_tags) AS calls_with_business_tag,
    (SELECT ROUND(AVG(tags_cnt), 2) FROM valid_calls) AS avg_tags_per_call
FROM business_tags
GROUP BY tag
ORDER BY tag;
--"details" | 23 | 0 | 108| 4.00
--"follow_up" | 29| 0| 108 | 4.00
--"interview" | 31| 0| 108 | 4.00
-- "screening"| 25| 0| 108 | 4.00

-- Задание 6.2. Метаданные сообщений 
WITH employer_messages_7d AS (
    SELECT
        m.message_id,
        m.message_meta
    FROM messages AS m
    JOIN responses AS r
    ON m.response_id = r.response_id
    WHERE m.sender_role = 'employer' AND m.sent_at >= r.created_at
        AND m.sent_at < r.created_at + INTERVAL '7 day'
),
messages_meta AS (
    SELECT
        message_id,
        COALESCE(message_meta ->> 'channel', 'нет канала') AS channel,
        (message_meta ->> 'is_read')::boolean AS is_read,
        COALESCE(jsonb_array_length(message_meta -> 'attachments'), 0) AS attachments_cnt
    FROM employer_messages_7d
)
SELECT
    channel,
    COUNT(*) AS messages_cnt,
    COUNT(is_read) AS read_flag_known_cnt,
    COUNT(*) FILTER (WHERE is_read = false) AS unread_cnt,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_read = false) / NULLIF(COUNT(is_read), 0), 1) AS unread_share,
    COUNT(*) FILTER (WHERE attachments_cnt > 0) AS with_attachments_cnt,
    ROUND(100.0 * COUNT(*) FILTER (WHERE attachments_cnt > 0) / COUNT(*), 1) AS with_attachments_share
FROM messages_meta
GROUP BY channel
ORDER BY channel;

-- mobile_app| 360 | 360 | 36 | 10.0 | 14 | 3.9
-- web| 628 | 628 | 52 | 8.3 | 25 |	4.0
-- mobile_app: 360 сообщений, прочтение известно у 360, непрочитанных 36, с вложением 14
-- web: 628 сообщений, прочтение известно у 628, непрочитанных 52 - это 8.3%, с вложением 25 - это 4%
-- Сообщений без канала не нашлось. Через web пишут почти в 2 раза чаще

-- ============================================================
-- Блок Д. Самостоятельное исследование
-- ============================================================

-- Задание 7
-- Гипотеза 1: кандидаты, которых пригласили  в первую неделю после отклика пишут работодателю больше сообщений, чем кандидаты, которым отказали
-- Гипотеза 2: у приглашённых кандидатов первый контакт от работодателя чаще был звонком, чем у тех, кому отказали.

-- Три характееристики:
-- 1. среднее и медиана числа сообщений кандидата в первые 7 дней после отклика
-- 2. доля откликов, где кандидат написал хотя бы одно сообщение
-- 3. доля откликов, где первый контакт от работодателя был звонком

-- Расчет гипотезы 1 
WITH applicant_messages_7d AS (
    SELECT
        m.response_id,
        COUNT(*) AS applicant_messages_cnt
    FROM messages AS m
    JOIN responses AS r
        ON m.response_id = r.response_id
    WHERE m.sender_role = 'applicant' AND m.sent_at >= r.created_at
        AND m.sent_at < r.created_at + INTERVAL '7 day'
    GROUP BY m.response_id
),
responses_activity AS (
    SELECT
        r.response_id,
        r.status,
        COALESCE(am.applicant_messages_cnt, 0) AS applicant_messages_cnt
    FROM responses AS r
    LEFT JOIN applicant_messages_7d AS am
     ON r.response_id = am.response_id
    WHERE r.status IN ('invited', 'rejected')
)


SELECT
    status,
    COUNT(*) AS responses_cnt,
    ROUND(AVG(applicant_messages_cnt), 2) AS avg_applicant_messages,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY applicant_messages_cnt) AS median_applicant_messages,
    ROUND(100.0 * COUNT(*) FILTER (WHERE applicant_messages_cnt > 0) / COUNT(*), 1) AS share_with_messages
FROM responses_activity
GROUP BY status
ORDER BY status;
-- invited | 92 | 1.47 | 2 | 51.1
-- rejected | 260 | 1.60 | 2 | 55.8
-- Вывод: гипотеза не подтверждается
-- Приглашённые кандидаты писали в среднем 1.47 сообщения, а те, кому отказали -1.60.
-- Медиана у обеих групп одинаковая — 2, а доля откликов хотя бы с одним сообщением у приглашённых даже ниже: 51.1% против 55.8%. То есть активность кандидата в переписке с приглашением не связана


-- Расчет гипотезы 2
WITH employer_messages_7d AS (
    SELECT
        m.response_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN responses AS r
    ON m.response_id = r.response_id
    WHERE m.sender_role = 'employer' AND m.sent_at >= r.created_at AND m.sent_at < r.created_at + INTERVAL '7 day'
),
employer_calls_7d AS (
    SELECT
        c.response_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN responses AS r
        ON c.response_id = r.response_id
    WHERE c.caller_role = 'employer'
        AND c.call_at >= r.created_at
        AND c.call_at < r.created_at + INTERVAL '7 day'
),
employer_events_7d AS (
    SELECT response_id, event_id, event_at, event_type
    FROM employer_messages_7d
    UNION ALL
    SELECT response_id, event_id, event_at, event_type
    FROM employer_calls_7d
),
events_numbered AS (
    SELECT
        response_id,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS event_num
    FROM employer_events_7d
),
first_events AS (
    -- одна строка = первый контакт работодателя по отклику
    SELECT
        response_id,
        event_type AS first_event_type
    FROM events_numbered
    WHERE event_num = 1
)
SELECT
    r.status,
    COUNT(*) AS responses_with_events_cnt,
    COUNT(*) FILTER (WHERE fe.first_event_type = 'call') AS first_call_cnt,
    ROUND(100.0 * COUNT(*) FILTER (WHERE fe.first_event_type = 'call') / COUNT(*), 1) AS first_call_share
FROM first_events AS fe
JOIN responses AS r
ON fe.response_id = r.response_id
WHERE r.status IN ('invited', 'rejected')
GROUP BY r.status
ORDER BY r.status;
-- invited | 54 | 11 | 20.4
-- rejected | 157 | 25 | 15.9
-- Вывод: данных недостаточно
-- У приглашённых первый контакт был звонком в 20.4% случаев, у тех кому отказали - в 15.9%.
-- Да, у приглашённых звонок первым встречается чаще, но таких откликов всего 11. Если бы звонков было
-- хотя бы на 2 меньше, доля упала бы до 16.7% и почти сравнялась с отказами. Поэтому я не могу сказать, что гипотеза подтверждается.


-- Задание 8
-- Получается, что работодатели обрабатывают отклики неравномерно: у 246 из 628 откликов за первую неделю не было ни одного контакта со стороны работодателя. Когда работодатель всё-таки выходит на связь, то почти всегда начинает с сообщения: так начинаются 314 из 382 обработанных откликов а всего за первую неделю было 988 сообщений и только 108 звонков. До первого контакта обычно проходит 2–3 дня ,а в уже начатой переписке работодатели отвечают кандидату быстрее: медиана около 4 часов.
-- Различия между работодателями большие даже внутри одного направления: например, у аналитиков данных один работодатель отвечает на 89.5% откликов, а другой только на 36%.
-- По заданию 7 мне не удалось найти особенность коммуникации, которая явно связана с приглашением: приглашённые кандидаты писали не больше остальных и это видно по данным: 1.47 сообщения против 1.60 , а первый звонок у приглашённых встречается чаще 20.4% против 15.9%.  Но данный показатель всего у 11 откликов, и разница может быть случайной.
-- Главное ограничение анализа, как мне кажется : в данных нет времени приглашения, есть только итоговый статус, поэтому нельзя понять, что было раньше: коммуникация или решение.
-- Следующим шагом я бы запросил время смены статуса отклика и проверил, связана ли скорость первого контакта с тем, пригласят ли кандидата


