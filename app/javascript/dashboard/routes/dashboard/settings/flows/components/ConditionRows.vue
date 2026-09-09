<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Kept to the attributes and operators AutomationRules::ConditionsFilterService resolves without
// extra context, since a flow condition is evaluated mid-conversation rather than on an event.
const ATTRIBUTES = [
  'status',
  'priority',
  'labels',
  'content',
  'browser_language',
  'country_code',
  'city',
  'email',
  'phone_number',
  'company_name',
];

const OPERATORS = [
  'equal_to',
  'not_equal_to',
  'contains',
  'does_not_contain',
  'starts_with',
  'is_present',
  'is_not_present',
];

const VALUELESS_OPERATORS = ['is_present', 'is_not_present'];

const conditions = defineModel({ type: Array, required: true });

const { t } = useI18n();

const attributeOptions = computed(() =>
  ATTRIBUTES.map(value => ({
    value,
    label: t(`FLOWS.CONDITION_ATTRIBUTES.${value.toUpperCase()}`),
  }))
);

const operatorOptions = computed(() =>
  OPERATORS.map(value => ({
    value,
    label: t(`FLOWS.CONDITION_OPERATORS.${value.toUpperCase()}`),
  }))
);

const valuesText = index => ({
  get: () => (conditions.value[index].values ?? []).join(', '),
  set: raw => {
    conditions.value[index].values = raw
      .split(',')
      .map(value => value.trim())
      .filter(Boolean);
  },
});

const addCondition = () => {
  // Every condition after the first needs a joiner; the engine reads it off the preceding row.
  if (conditions.value.length) {
    conditions.value[conditions.value.length - 1].query_operator = 'AND';
  }
  conditions.value.push({
    attribute_key: 'status',
    filter_operator: 'equal_to',
    values: [],
    query_operator: null,
  });
};

const removeCondition = index => {
  conditions.value.splice(index, 1);
  if (conditions.value.length) {
    conditions.value[conditions.value.length - 1].query_operator = null;
  }
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <span class="text-sm text-n-slate-12">
      {{ t('FLOWS.EDITOR.INSPECTOR.CONDITIONS') }}
    </span>

    <div
      v-for="(condition, index) in conditions"
      :key="index"
      class="flex flex-col gap-2 rounded-lg border border-n-weak p-2"
    >
      <Select v-model="condition.attribute_key" :options="attributeOptions" />
      <Select v-model="condition.filter_operator" :options="operatorOptions" />
      <Input
        v-if="!VALUELESS_OPERATORS.includes(condition.filter_operator)"
        :model-value="valuesText(index).get()"
        size="sm"
        :placeholder="t('FLOWS.EDITOR.INSPECTOR.VALUES_PLACEHOLDER')"
        @update:model-value="valuesText(index).set($event)"
      />
      <div class="flex items-center justify-between">
        <Select
          v-if="index < conditions.length - 1"
          v-model="condition.query_operator"
          :options="[
            { value: 'AND', label: t('FLOWS.CONDITION_OPERATORS.AND') },
            { value: 'OR', label: t('FLOWS.CONDITION_OPERATORS.OR') },
          ]"
        />
        <span v-else />
        <Button
          icon="i-lucide-trash-2"
          size="sm"
          color="ruby"
          variant="ghost"
          @click="removeCondition(index)"
        />
      </div>
    </div>

    <Button
      :label="t('FLOWS.EDITOR.INSPECTOR.ADD_CONDITION')"
      icon="i-lucide-plus"
      size="sm"
      variant="faded"
      @click="addCondition"
    />
  </div>
</template>
