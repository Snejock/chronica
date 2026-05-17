---
title: Таблица. Новости. 2
queries:
  - uniq_news: uniq_news.sql
---

<script>
  // Функция для красивого форматирования даты в локальном времени браузера
  const formatDate = (dateStr, lang) => {
    if (!dateStr) return '';
    
    // JS корректно поймет, что это UTC, благодаря букве 'Z' из SQL-запроса, 
    // и сам переведет в локальный часовой пояс компьютера пользователя.
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

  // РЕАКТИВНОСТЬ SVELTE: 
  // Когда SQL-запрос last20_news загрузится или изменится язык, этот блок выполнится заново.
  // Создаем новый массив с добавленной колонкой local_date
  $: localized_news = last20_news ? Array.from(last20_news).map(row => ({
    ...row,
    local_date: formatDate(row.iso_utc, inputs.selected_lang?.value || 'ru')
  })) : [];

</script>

<!-- Выбор языка -->
<Dropdown name="selected_lang" defaultValue="ru">
    <DropdownOption value="ru" label="Русский"/>
    <DropdownOption value="en" label="English"/>
</Dropdown>

```sql last20_news
SELECT
    *
    , strftime(published_utc, '%Y-%m-%dT%H:%M:%SZ') AS iso_utc
FROM ${uniq_news}
WHERE language_code = '${inputs.selected_lang.value}'
ORDER BY published_utc DESC
LIMIT 50
```

### Лента новостей

<DataTable data={localized_news} search={true} rows={20}>
    <Column id="local_date" title="Дата" />
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