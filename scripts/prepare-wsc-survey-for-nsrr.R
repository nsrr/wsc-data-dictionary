library(dplyr)
library(tidyr)
library(readxl)


### For preparing the new mailed survey dataset
surveydir <- "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_source/2025_covariates/NSRR_MAILED_SURVEYS_data_2025_0702.xlsx"
df_survey <- read_xlsx(surveydir)|>
  rename_with(tolower)

df_survey_clean <- df_survey|>
  mutate(wsc_vst = 6)|>
  relocate(wsc_vst, .after = agency)

write.csv(df_survey_clean, "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_releases/0.8.0.pre/wsc-mailed-survey-dataset-0.8.0.pre.csv", row.names = F, na = "")


###--------- Long Survey Format doesn't work -------
# df_survery_long <- df_survey|>
#   pivot_longer(
#     # grab any columns that end with _S1/_S2/_S3
#     cols = -c(wsc_id, agency),
#     names_to = c(".value", "survey"),
#     names_pattern = "^(.*)_(s[123])$",
#     values_drop_na = FALSE)|>
#   mutate(wsc_vst = case_match(survey,
#                             "s1" ~ "61",
#                             "s2" ~ "62",
#                             "s3" ~ "63"),
#          survery_completed = ifelse(is.na(survey_year), 0, 1))|>
#   relocate(wsc_vst, .after = agency)|>
#   relocate(survery_completed, .after = survey)|>
#   arrange(wsc_id, wsc_vst)





