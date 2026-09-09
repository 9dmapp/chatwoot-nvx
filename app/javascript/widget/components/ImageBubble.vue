<script>
import ImageViewer from 'widget/components/ImageViewer.vue';

export default {
  components: { ImageViewer },
  props: {
    url: { type: String, default: '' },
    thumb: { type: String, default: '' },
    readableTime: { type: String, default: '' },
  },
  emits: ['error'],
  data() {
    return { isViewerOpen: false };
  },
  methods: {
    onImgError() {
      this.$emit('error');
    },
  },
};
</script>

<template>
  <button type="button" class="image" @click="isViewerOpen = true">
    <div class="wrap">
      <img :src="thumb" alt="Picture message" @error="onImgError" />
      <span class="time">{{ readableTime }}</span>
    </div>
  </button>
  <ImageViewer v-if="isViewerOpen" :url="url" @close="isViewerOpen = false" />
</template>

<style lang="scss" scoped>
.image {
  @apply block cursor-zoom-in p-0 bg-transparent border-0 w-full;

  .wrap {
    position: relative;
    display: flex;
    max-width: 100%;

    &::before {
      background-image: linear-gradient(-180deg, transparent 3%, #1f2d3d 130%);
      bottom: 0;
      content: '';
      height: 20%;
      left: 0;
      opacity: 0.8;
      position: absolute;
      width: 100%;
    }
  }

  img {
    width: 100%;
    max-width: 250px;
  }

  .time {
    @apply text-xs bottom-1 text-white ltr:right-3 rtl:left-3 whitespace-nowrap absolute;
  }
}
</style>
