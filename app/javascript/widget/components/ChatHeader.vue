<script setup>
import { computed, toRef } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import HeaderActions from './HeaderActions.vue';
import AvailabilityContainer from 'widget/components/Availability/AvailabilityContainer.vue';
import { useAvailability } from 'widget/composables/useAvailability';

const props = defineProps({
  avatarUrl: { type: String, default: '' },
  title: { type: String, default: '' },
  showPopoutButton: { type: Boolean, default: false },
  showBackButton: { type: Boolean, default: false },
  availableAgents: { type: Array, default: () => [] },
  agent: { type: Object, default: null },
});

const availableAgents = toRef(props, 'availableAgents');

const router = useRouter();
const { t } = useI18n();
const { isOnline } = useAvailability(availableAgents);

// Once someone has replied, the header names that person instead of the website: a face and a
// name carry far more reassurance than the inbox title.
const displayName = computed(
  () => props.agent?.available_name || props.agent?.name || props.title
);
const displayAvatarUrl = computed(
  () => props.agent?.avatar_url || props.avatarUrl
);
const hasAgentIdentity = computed(() => !!props.agent);

const onBackButtonClick = () => {
  router.replace({ name: 'home' });
};
</script>

<template>
  <header class="flex justify-between w-full p-5 bg-transparent gap-2">
    <div class="flex items-center">
      <button
        v-if="showBackButton"
        class="px-2 ltr:-ml-3 rtl:-mr-3"
        @click="onBackButtonClick"
      >
        <FluentIcon icon="chevron-left" size="24" class="text-n-slate-12" />
      </button>
      <!-- Avatar, not a bare img: an agent's avatar can 404 and initials are a better fallback
        than a broken-image glyph in the one place the visitor looks for a face. -->
      <Avatar
        v-if="displayAvatarUrl || agent"
        class="ltr:mr-3 rtl:ml-3"
        :src="displayAvatarUrl"
        :name="displayName"
        :size="32"
        rounded-full
      />
      <div class="flex flex-col gap-1">
        <div
          class="flex items-center text-base font-medium leading-4 text-n-slate-12"
        >
          <!-- The website name is admin-authored markup; an agent name is a plain string. -->
          <span v-if="hasAgentIdentity" class="ltr:mr-1 rtl:ml-1">
            {{ displayName }}
          </span>
          <span
            v-else
            v-dompurify-html="displayName"
            class="ltr:mr-1 rtl:ml-1"
          />
          <div
            v-if="isOnline"
            class="flex items-center gap-1 text-xs font-normal text-n-teal-11"
          >
            <div class="h-2 w-2 rounded-full bg-n-teal-10" />
            {{ t('TEAM_AVAILABILITY.STATUS_ONLINE') }}
          </div>
        </div>
        <AvailabilityContainer
          :agents="availableAgents"
          :show-header="false"
          :show-avatars="false"
          text-classes="text-xs leading-3"
        />
      </div>
    </div>
    <HeaderActions :show-popout-button="showPopoutButton" />
  </header>
</template>
