// Пользовательский конфиг подмешивается Evidence в сгенерированный
// .evidence/template/svelte.config.js (см. loadUserConfiguration там же).

/** @type {import('@sveltejs/kit').Config} */
export default {
  kit: {
    prerender: {
      // По умолчанию SvelteKit валит ВЕСЬ статический билд, если хотя бы одна
      // обнаруженная ссылка (например /stories/<id>/locations/<location_id>
      // или /stories/<id>/actors/<actor_id>) при пререндере ответила не 200 —
      // так один проблемный актор/локация кладёт весь сайт (см. инцидент
      // с 404 на проде: 500 при пререндере одной страницы локации оборвал
      // всю сборку, прод остался на предыдущем релизе). Вместо этого логируем
      // и пропускаем именно эту страницу — остальной сайт собирается и
      // деплоится штатно.
      handleHttpError: ({ status, path, message }) => {
        console.warn(`[prerender] skipping ${path}: ${status} ${message}`);
      }
    }
  }
};
