<script setup>
import { onBeforeUnmount, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { IFrameHelper } from 'widget/helpers/utils';

const props = defineProps({
  url: { type: String, required: true },
});

const emit = defineEmits(['close']);
const { t } = useI18n();

const onKeydown = event => {
  if (event.key === 'Escape') emit('close');
};

// The widget is its own document, so this overlay can only cover the panel. The panel is asked
// to take the whole viewport for as long as the image is up, which is what makes it full screen
// rather than full-panel. On the standalone widget page there is no parent to ask, and none is
// needed - the page is already the viewport.
const setParentFullScreen = enabled => {
  if (!IFrameHelper.isIFrame()) return;

  IFrameHelper.sendMessage({ event: 'setFullScreen', enabled });
};

// Scrolling the conversation behind the image would be disorienting, so it is frozen too.
onMounted(() => {
  document.addEventListener('keydown', onKeydown);
  document.documentElement.style.overflow = 'hidden';
  setParentFullScreen(true);
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown);
  document.documentElement.style.overflow = '';
  setParentFullScreen(false);
});
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-[rgba(0,0,0,0.85)]"
    role="dialog"
    aria-modal="true"
    @click.self="emit('close')"
  >
    <img
      :src="props.url"
      alt=""
      class="max-w-full max-h-full object-contain rounded-[0.45rem]"
      @click.stop
    />
    <button
      class="absolute flex items-center justify-center rounded-full top-3 end-3 size-9 bg-n-alpha-black2 text-n-slate-1 hover:bg-n-alpha-black1"
      :aria-label="t('IMAGE_VIEWER.CLOSE')"
      @click="emit('close')"
    >
      <i class="i-lucide-x size-5" />
    </button>
    <a
      :href="props.url"
      target="_blank"
      rel="noopener noreferrer nofollow"
      class="absolute text-xs underline bottom-4 text-n-slate-1/80 hover:text-n-slate-1"
      @click.stop
    >
      {{ t('IMAGE_VIEWER.OPEN_ORIGINAL') }}
    </a>
  </div>
</template>
