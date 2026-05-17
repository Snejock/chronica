---
title: Аккордеон. Новости
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
FROM ${uniq_news}
WHERE language_code = '${inputs.selected_lang.value}'
ORDER BY published_utc DESC
LIMIT 20
```

### Лента новостей

{#if last20_news.length > 0}
  <Accordion class="rounded-xl bg-gray-50 px-4 mt-4">
    {#each last20_news as news}
      <AccordionItem 
        title="{formatDate(news.published_utc, inputs.selected_lang.value)} | {news.title_txt}" 
        class="border-none text-left [&_summary]:text-left [&_button]:text-left [&_summary]:flex [&_summary]:justify-between [&_summary]:items-center"
      >
        <p>{news.summary_txt}</p>
        <p class="mt-2"><em>Источник: {news.feed_nm}</em></p>
      </AccordionItem>
    {/each}
  </Accordion>
{:else}
  <p class="mt-4 italic text-left">Новостей на этом языке пока нет.</p>
{/if}




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