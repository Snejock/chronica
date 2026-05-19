<script>
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  export let data;
</script>

<EvidenceDefaultLayout {data} logo="/logo.svg">
  <slot slot="content" />
</EvidenceDefaultLayout>
