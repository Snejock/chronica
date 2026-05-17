---
title: Таблица. Новости
queries:
  - uniq_news: uniq_news.sql
---

<script>
  // Функция для красивого форматирования даты
  const formatDate = (dateStr, lang) => {
    const date = new Date(dateStr);
    return date.toLocaleString(lang === 'ru' ? 'ru-RU' : 'en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const i18n = {
    ru: {
      page_title: "Последние новости",
      col_date: "Дата",
      col_title: "Заголовок",
      col_summary: "Содержание"
    },
    en: {
      page_title: "Latest News",
      col_date: "Date",
      col_title: "Headline",
      col_summary: "Summary"
    }
  };
</script>

<!-- Выбор языка -->
<Dropdown name="selected_lang" defaultValue="ru">
    <DropdownOption value="ru" label="Русский"/>
    <DropdownOption value="en" label="English"/>
</Dropdown>

```sql last20_news
SELECT
    *
    , strftime(published_utc, '%d.%m.%Y %H:%M') formatted_date
FROM ${uniq_news}
WHERE language_code = '${inputs.selected_lang.value}'
ORDER BY published_utc DESC
LIMIT 20
```

### Лента новостей

<DataTable data={last20_news} search={true} rows={20}>
    <Column id="formatted_date" title="Дата" />
    <Column id="feed_nm" title="Источник" />
    <Column id="title_txt" title="Заголовок" />
    <Column id="summary_txt" title="Содержание" />
</DataTable>




---

<Details title="🛠 Техническая информация (Отладка)">

Здесь выводятся внутренние переменные состояния страницы для проверки корректности работы фильтров.

**Текущие параметры (Inputs):**
* Выбранный язык: **{inputs.selected_lang.value}**

**Статус таблиц:**
```sql debug_counts
SELECT 
    'uniq_news' AS table_name,
    count(*) AS total_rows,
    max(published_utc) AS last_record_time
FROM ${uniq_news}
```
<DataTable data={debug_counts} />
</Details>