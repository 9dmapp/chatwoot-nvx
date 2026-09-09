<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { LocalStorage } from 'shared/helpers/localStorage';

const DISMISSED_KEY = 'chatwoot_dismissed_announcement';
// Roughly how long one character should take to cross the bar. Pacing the animation by content
// length keeps a short promo from whipping past and a long one from crawling.
const SECONDS_PER_CHARACTER = 0.22;
const MIN_DURATION_SECONDS = 12;

const { t } = useI18n();

const channelConfig = computed(() => window.chatwootWebChannel || {});
const announcement = computed(() => channelConfig.value.announcement || '');
const announcementUrl = computed(
  () => channelConfig.value.announcementUrl || ''
);
// `_top` rather than `_self`: the widget usually runs inside the host page's iframe, so the
// visitor's idea of "this tab" is the page around it, not the frame.
const linkTarget = computed(() =>
  channelConfig.value.announcementLinkTarget === 'current_tab'
    ? '_top'
    : '_blank'
);

// Keyed by the announcement itself, so publishing a new one brings the bar back for everyone
// who dismissed the previous one.
const dismissed = ref(LocalStorage.get(DISMISSED_KEY));

const isVisible = computed(
  () => !!announcement.value && dismissed.value !== announcement.value
);

const scrollDuration = computed(
  () =>
    `${Math.max(MIN_DURATION_SECONDS, announcement.value.length * SECONDS_PER_CHARACTER)}s`
);

const dismiss = () => {
  LocalStorage.set(DISMISSED_KEY, announcement.value);
  dismissed.value = announcement.value;
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div
    v-if="isVisible"
    class="absolute z-20 flex items-center gap-2 py-1 rounded-full shadow-md inset-x-3 top-2 bg-gradient-to-r from-[var(--widget-color)] to-[var(--widget-color-soft)]"
  >
    <i
      class="flex-shrink-0 ms-3 i-lucide-bell size-3.5 text-[var(--widget-color-contrast)]"
    />
    <!--
      The marquee is two identical copies of the text sliding left by exactly half the track:
      when the first copy leaves, the second is precisely where the first started, so the loop
      has no visible seam and no measurement in JS.
    -->
    <component
      :is="announcementUrl ? 'a' : 'div'"
      :href="announcementUrl || undefined"
      :target="announcementUrl ? linkTarget : undefined"
      :rel="announcementUrl ? 'noopener nofollow noreferrer' : undefined"
      class="flex-1 min-w-0 overflow-hidden marquee"
      :class="{ 'cursor-pointer': announcementUrl }"
    >
      <div
        class="flex w-max marquee-track"
        :style="{ '--marquee-duration': scrollDuration }"
      >
        <span
          class="px-3 text-[0.75rem] leading-4 whitespace-nowrap text-[var(--widget-color-contrast)]"
          :class="{ 'underline underline-offset-2': announcementUrl }"
        >
          {{ announcement }}
        </span>
        <span
          aria-hidden="true"
          class="px-3 text-[0.75rem] leading-4 whitespace-nowrap text-[var(--widget-color-contrast)]"
          :class="{ 'underline underline-offset-2': announcementUrl }"
        >
          {{ announcement }}
        </span>
      </div>
    </component>
    <button
      class="flex-shrink-0 me-3 text-[var(--widget-color-contrast)] opacity-70 hover:opacity-100"
      :aria-label="t('ANNOUNCEMENT.DISMISS')"
      @click="dismiss"
    >
      <i class="i-lucide-x size-3.5" />
    </button>
  </div>
</template>

<style scoped lang="scss">
/*
 * A keyframe rather than a Tailwind utility: the distance is -50% of a track whose width depends
 * on the announcement text, so it cannot be expressed as a fixed value in the config.
 */
@keyframes marquee-scroll {
  from {
    transform: translateX(0);
  }

  to {
    transform: translateX(-50%);
  }
}

.marquee-track {
  animation: marquee-scroll var(--marquee-duration) linear infinite;
}

.marquee:hover .marquee-track {
  animation-play-state: paused;
}

/* Static and readable when the visitor has asked for less motion. */
@media (prefers-reduced-motion: reduce) {
  .marquee {
    @apply overflow-x-auto;
  }

  .marquee-track {
    animation: none;
  }

  .marquee-track span[aria-hidden='true'] {
    @apply hidden;
  }
}
</style>
