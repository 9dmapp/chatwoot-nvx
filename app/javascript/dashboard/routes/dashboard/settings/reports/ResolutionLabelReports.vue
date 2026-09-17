<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ReportsAPI from 'dashboard/api/reports';
import ReportHeader from './components/ReportHeader.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();

// Ranges are expressed in days back from now, which is all this report needs; the built-in
// reports' date picker carries comparison periods and business-hours handling that do not apply.
const RANGE_OPTIONS = [7, 30, 90, 365];

const days = ref(30);
const isLoading = ref(false);
const report = ref({ labels: [], unlabelled: 0, total_resolutions: 0 });

const rangeOptions = computed(() =>
  RANGE_OPTIONS.map(value => ({
    value,
    label: t('RESOLUTION_LABEL_REPORTS.RANGE', { days: value }),
  }))
);

const rows = computed(() => report.value.labels ?? []);
const total = computed(() => report.value.total_resolutions ?? 0);

// Share is of resolutions, not of labels: one resolution carrying two labels counts towards both,
// so the percentages can legitimately add up to more than a hundred.
const share = count =>
  total.value ? Math.round((count / total.value) * 1000) / 10 : 0;

const fetchReport = async () => {
  isLoading.value = true;
  try {
    const until = Math.floor(Date.now() / 1000);
    const since = until - days.value * 24 * 60 * 60;
    const { data } = await ReportsAPI.getResolutionLabels({ since, until });
    report.value = data;
  } finally {
    isLoading.value = false;
  }
};

watch(days, fetchReport);
onMounted(fetchReport);
</script>

<template>
  <ReportHeader
    :header-title="$t('RESOLUTION_LABEL_REPORTS.HEADER')"
    :header-description="$t('RESOLUTION_LABEL_REPORTS.DESCRIPTION')"
  >
    <Select v-model="days" :options="rangeOptions" />
  </ReportHeader>

  <div v-if="isLoading" class="flex justify-center py-10">
    <Spinner />
  </div>

  <div v-else class="flex flex-col gap-4">
    <div class="flex gap-3">
      <div
        class="flex flex-col gap-1 rounded-xl border border-solid border-n-weak bg-n-solid-1 px-4 py-3"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('RESOLUTION_LABEL_REPORTS.TOTAL') }}
        </span>
        <span class="text-lg font-medium text-n-slate-12 tabular-nums">
          {{ total }}
        </span>
      </div>
      <div
        class="flex flex-col gap-1 rounded-xl border border-solid border-n-weak bg-n-solid-1 px-4 py-3"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('RESOLUTION_LABEL_REPORTS.UNLABELLED') }}
        </span>
        <span class="text-lg font-medium text-n-slate-12 tabular-nums">
          {{ report.unlabelled }}
        </span>
      </div>
    </div>

    <p v-if="!rows.length" class="text-sm text-n-slate-11">
      {{ $t('RESOLUTION_LABEL_REPORTS.EMPTY') }}
    </p>

    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-xs text-n-slate-11">
          <th class="py-2 text-start font-medium">
            {{ $t('RESOLUTION_LABEL_REPORTS.LABEL') }}
          </th>
          <th class="py-2 text-end font-medium">
            {{ $t('RESOLUTION_LABEL_REPORTS.COUNT') }}
          </th>
          <th class="w-1/2 py-2 text-end font-medium">
            {{ $t('RESOLUTION_LABEL_REPORTS.SHARE') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="row.label"
          class="border-t border-solid border-n-weak"
        >
          <td class="py-2 text-n-slate-12">{{ row.label }}</td>
          <td class="py-2 text-end tabular-nums text-n-slate-12">
            {{ row.count }}
          </td>
          <td class="py-2">
            <div class="flex items-center justify-end gap-2">
              <div class="h-1.5 w-full max-w-48 rounded bg-n-alpha-2">
                <div
                  class="h-1.5 rounded bg-n-brand"
                  :style="{ width: `${Math.min(share(row.count), 100)}%` }"
                />
              </div>
              <span class="w-12 text-end tabular-nums text-n-slate-11">
                {{ share(row.count) }}%
              </span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
