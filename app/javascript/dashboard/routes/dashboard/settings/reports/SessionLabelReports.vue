<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ReportsAPI from 'dashboard/api/reports';
import ReportHeader from './components/ReportHeader.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();

const RANGE_OPTIONS = [7, 30, 90, 365];

const days = ref(30);
const isLoading = ref(false);
const inboxes = ref([]);

const rangeOptions = computed(() =>
  RANGE_OPTIONS.map(value => ({
    value,
    label: t('SESSION_LABEL_REPORTS.RANGE', { days: value }),
  }))
);

// An inbox nobody closed a chat in tells the reader nothing, so it is left out rather than
// listed as a row of zeroes.
const rows = computed(() =>
  inboxes.value.filter(inbox => inbox.total_sessions > 0)
);

const share = (count, total) =>
  total ? Math.round((count / total) * 1000) / 10 : 0;

const fetchReport = async () => {
  isLoading.value = true;
  try {
    const until = Math.floor(Date.now() / 1000);
    const since = until - days.value * 24 * 60 * 60;
    const { data } = await ReportsAPI.getSessionLabels({ since, until });
    inboxes.value = data.inboxes ?? [];
  } finally {
    isLoading.value = false;
  }
};

watch(days, fetchReport);
onMounted(fetchReport);
</script>

<template>
  <ReportHeader
    :header-title="t('SESSION_LABEL_REPORTS.HEADER')"
    :header-description="t('SESSION_LABEL_REPORTS.DESCRIPTION')"
  >
    <Select v-model="days" :options="rangeOptions" />
  </ReportHeader>

  <div v-if="isLoading" class="flex justify-center py-10">
    <Spinner />
  </div>

  <p v-else-if="!rows.length" class="text-sm text-n-slate-11">
    {{ t('SESSION_LABEL_REPORTS.EMPTY') }}
  </p>

  <div v-else class="flex flex-col gap-6">
    <section
      v-for="inbox in rows"
      :key="inbox.inbox_id"
      class="flex flex-col gap-3 rounded-xl border border-solid border-n-weak bg-n-solid-1 p-4"
    >
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ inbox.inbox_name }}
        </h3>
        <p class="text-xs text-n-slate-11">
          {{
            t('SESSION_LABEL_REPORTS.SUMMARY', {
              sessions: inbox.total_sessions,
              unlabelled: inbox.unlabelled,
            })
          }}
        </p>
      </div>

      <p v-if="!inbox.labels.length" class="text-sm text-n-slate-11">
        {{ t('SESSION_LABEL_REPORTS.NONE_LABELLED') }}
      </p>

      <table v-else class="w-full text-sm">
        <tbody>
          <tr v-for="label in inbox.labels" :key="label.id">
            <td class="py-1.5 pe-3 text-n-slate-12">{{ label.label }}</td>
            <td class="w-14 py-1.5 text-end tabular-nums text-n-slate-12">
              {{ label.count }}
            </td>
            <td class="w-1/2 py-1.5">
              <div class="flex items-center gap-2">
                <div class="h-1.5 w-full rounded bg-n-alpha-2">
                  <div
                    class="h-1.5 rounded bg-n-brand"
                    :style="{
                      width: `${share(label.count, inbox.total_sessions)}%`,
                    }"
                  />
                </div>
                <span class="w-12 text-end tabular-nums text-n-slate-11">
                  {{ share(label.count, inbox.total_sessions) }}%
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
