---
title: Таблица. RSS ленты
queries:
  - rss_feeds: rss_feeds.sql
---

```sql feeds
SELECT
    *
FROM ${rss_feeds}
```

### Лента новостей

<DataTable data={feeds} search={true} rows={100}>
    <Column id="feed_id" title="ID" />
    <Column id="feed_nm" title="Название" />
    <Column id="feed_type" title="Тип" />
    <Column id="country_code" title="Код страны" />
    <Column id="city_nm" title="Город" />
    <Column id="language_code" title="Код языка" />
</DataTable>




---

<Details title="🛠 Техническая информация (Отладка)">

Здесь выводятся внутренние переменные состояния страницы для проверки корректности работы фильтров.

**Текущие параметры (Inputs):**

**Статус таблиц:**
```sql debug_counts
SELECT 
    'rss_feeds' AS table_name,
    count(*) AS total_rows
FROM ${rss_feeds}
```
<DataTable data={debug_counts} />
</Details>