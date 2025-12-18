library(dplyr)
library(lubridate)
library(haven)
library(stringr)
library(hms)
library(readxl)
library(purrr)

wscs_path <- "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_source"
wscd_path <- "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_datasets"
wsca_path <- "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_archive"

version <- "0.8.0"
releasepath <- "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_releases"

wsc_in <- read_sas(file.path(wscs_path, "nsrr_wsc_2024_0711.sas7bdat"))|>
  mutate(across(where(is.character), ~ na_if(.x, "")))
wsc_mslt <- read_sas(file.path(wscs_path, "nsrr_mslt.sas7bdat"))|>
  mutate(across(where(is.character), ~ na_if(.x, "")))
wsc_drug <- read_sas(file.path(wscs_path, "nsrr_alldrugs.sas7bdat"))|>
  mutate(across(where(is.character), ~ na_if(.x, "")))


####------------------ Creating WSC Dataset + add drug and updated variables ------------------ 

wsc <- wsc_in |>
  rename_with(tolower)|> 
  mutate(
    wsc_id = as.numeric(wsc_id),
    wsc_vst = as.numeric(wsc_vst))|>
  distinct(wsc_id, wsc_vst, .keep_all = TRUE)|>
  arrange(wsc_id, wsc_vst)


wsc_drug <- wsc_drug |>
  rename_with(tolower)|>
  distinct(wsc_id, wsc_vst, .keep_all = TRUE) |>
  arrange(wsc_id, wsc_vst)

# Merge wsc and wsc_drug by wsc_id and wsc_vst, keep only rows in wsc
wsc_nsrr <- wsc |>
  left_join(wsc_drug, by = c("wsc_id", "wsc_vst"))|>
  mutate(apnea_treatment_year = as.numeric(apnea_treatment_year),
         reproductive_surg_year = as.numeric(reproductive_surg_year),
         apnea_year = as.numeric(apnea_year))|>
  mutate(across(everything(), ~ {
    attr(., "label") <- NULL
    .
  }))

# dat0.7.0 <- read.csv("/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_releases/0.7.0/wsc-dataset-0.7.0.csv")
# all.equal(dat0.7.0, wsc_nsrr, check.attributes = FALSE)

##Add in the new variables from 2025_0702

new_vars <- read_excel("/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_source/2025_covariates/wsc_new_vars.xlsx")|>
  select(id)|>
  keep(is.character) |>
  map(~tolower(.x))

my_vars <- unlist(new_vars)|>
  unname()

wsc_2025 <- read_excel("/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_source/2025_covariates/NSRR_WSC_data_2025_0702.xlsx", )|>
  rename_with(tolower)|> 
  select(c(wsc_id, wsc_vst, all_of(my_vars)))

wsc_nsrr_2025 <- wsc_nsrr|>
  left_join(wsc_2025, by = join_by(wsc_id, wsc_vst))


write.csv(wsc_nsrr_2025, file.path(releasepath, paste0(version, "/wsc-dataset-", version, ".csv")), na = "", row.names = F)


####------------------ Creating MSLT Dataset with hh:mm times  ------------------ 

wsc_mslt <- wsc_mslt |>
  rename_with(tolower)|>
  distinct(wsc_id, wsc_vst, .keep_all = TRUE) |>
  arrange(wsc_id, wsc_vst)

time_cols <- grep("time", names(wsc_mslt), value = TRUE)

convert_HHmm <- function(x) {
  # Treat blank "" as NA
  x[x == ""] <- NA
  
  ifelse(
    is.na(x),
    NA_character_,
    {
      x_str <- str_pad(as.character(x), 4, pad = "0")
      hrs <- substr(x_str, 1, 2)
      mins <- substr(x_str, 3, 4)
      paste0(hrs, ":", mins)
    }
  )
}

wsc_mslt_times <- wsc_mslt %>%
  mutate(across(all_of(time_cols), ~parse_hm(convert_HHmm(.x))))

wsc_mslt_merge <- wsc_mslt_times |>
  left_join(wsc_nsrr |> select(sex, race, wsc_id, wsc_vst), by = c("wsc_id", "wsc_vst"))|>
  mutate(across(everything(), ~ {
    attr(., "label") <- NULL
    .
  }))

# mslt0.7.0 <- read.csv("/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_releases/0.7.0/wsc-mslt-dataset-0.7.0.csv")
# all.equal( mslt0.7.0, wsc_mslt_merge, check.attributes = FALSE)

write.csv(wsc_mslt_merge, file.path(releasepath, paste0(version, "/wsc-mslt-dataset-", version, ".csv")), na = "", row.names = F)

####------------------ Creating NSRR Harmonized Dataset ------------------

wsc_harmonized <- wsc_nsrr|>
  mutate(
    nsrrid = wsc_id,
    nsrr_visit = wsc_vst,
    nsrr_age = ifelse(age > 89, 90, age),
    nsrr_age_gt89 = case_when(
           age > 89  ~ "yes",
           age <= 89 ~ "no"),
    nsrr_sex = case_match(sex, 
           "M" ~ "male",
           "F" ~ "female", 
           "." ~ "not reported"),
    nsrr_race = case_match(race,
                                0 ~ "asian",
                                1 ~ "black or african american",
                                2 ~ "hispanic",
                                3 ~ "american indian or alaska native",
                                5 ~ "white"),
    nsrr_bmi = bmi,
         # Clinical vitals
    nsrr_bp_systolic  = sbp_mean,
    nsrr_bp_diastolic = dbp_mean,
    nsrr_current_smoker = case_when(
           smoke_curr == "N" | (!is.na(smoke) & smoke == "N") ~ "no",
           smoke_curr == "Y" ~ "yes"),
    nsrr_ever_smoker = case_when(
           smoke == "N" ~ "no",
           smoke == "Y" ~ "yes"),
    nsrr_ahi_hp4u_aasm15 = ahi,
    nsrr_ahi_hp3u = ahi3,
    nsrr_tst_f1 = tst,
    nsrr_ttleffsp_f1 = se,
    nsrr_ttllatsp_f1 = sleep_latency,
    nsrr_ttlprdsp_s1sr = rem_latency,
    nsrr_waso_f1= waso,
    nsrr_pctdursp_s1 = pcttststagen1,
    nsrr_pctdursp_s2 = pcttststagen2,
    nsrr_pctdursp_s3 = pcttststage34,
    nsrr_pctdursp_sr = pcttstrem,
    nsrr_avgdurah_hp4u = mean_desat_dur,
    nsrr_pctdursp_salt90 = ptstl90,
    nsrr_avglvlsa = avgo2sattst,
    nsrr_minlvlsa = minsao2tst
    )|>
  select(
    nsrrid, nsrr_visit, wsc_vst,
    nsrr_age, nsrr_age_gt89, nsrr_sex, nsrr_race,
    nsrr_bmi,
    nsrr_bp_systolic, nsrr_bp_diastolic,
    nsrr_current_smoker, nsrr_ever_smoker,
    nsrr_ahi_hp4u_aasm15, nsrr_ahi_hp3u,
    nsrr_tst_f1, nsrr_ttleffsp_f1, nsrr_ttllatsp_f1,
    nsrr_ttlprdsp_s1sr, nsrr_waso_f1,
    nsrr_pctdursp_s1, nsrr_pctdursp_s2, nsrr_pctdursp_s3, nsrr_pctdursp_sr,
    nsrr_avgdurah_hp4u, nsrr_pctdursp_salt90, nsrr_avglvlsa, nsrr_minlvlsa)|>
  mutate(nsrr_file_prefix = paste0("wsc-visit", nsrr_visit, "-", nsrrid))|>
  mutate(across(everything(), ~ {
    attr(., "label") <- NULL
    .}))

#write.csv(wsc_harmonized, file.path(releasepath, paste0(version, "/wsc-harmonized-dataset-", version, ".csv")), na = "", row.names = F)

##this is to check if the R script output is the same as SAS 
#harm0.7.0 <- read.csv("/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_releases/0.7.0/wsc-harmonized-dataset-0.7.0.csv")
#all.equal(wsc_harmonized, harm0.7.0, check.attributes = FALSE)


###--- Prepare the survey
surveydir <- "/Volumes/bwh-sleepepi-nsrr-staging/20200115-peppard-wsc/nsrr-prep/_source/2025_covariates/NSRR_MAILED_SURVEYS_data_2025_0702.xlsx"
df_survey <- read_xlsx(surveydir)|>
  rename_with(tolower)

df_survey_clean <- df_survey|>
  mutate(wsc_vst = 0,
         q17b_s1 = case_when(
           q17b_s1 == 21 ~ 4,   # spring → April
           q17b_s1 == 22 ~ 7,   # summer → July
           q17b_s1 == 23 ~ 10,  # fall → October
           TRUE ~ q17b_s1 ))|>
  relocate(wsc_vst, .after = agency)|>
  arrange(wsc_id)


write.csv(df_survey_clean, file.path(releasepath, paste0(version, "/wsc-mailed-survey-dataset-", version, ".csv")), row.names = F, na = "")


###--- Transform survey into long format add add variables to harmonized dataset

df_survey_harmonized <- df_survey_clean |>
  #age, sex, current smoker, feet, inches, lbs
  select(wsc_id,
         q21_s1, q23_s1, q23a_s1, q24a_s1, q24b_s1, q25_s1,
         q22_s2, q25_s2, q25a_s2, q26a_s2, q26b_s2, q27_s2,
         q18_s3, q37a_s3, q37b_s3, q38a_s3, q38b_s3, q39_s3
         )

long_mapped <- df_survey_harmonized |>
  pivot_longer(-wsc_id,
               names_to = c("question"),
               values_to = "response")|>
  mutate(
    visit_num = str_extract(question, "(?<=_s)\\d+"),
    nsrr_visit = paste0("S", visit_num),
    measure = case_when(
      question %in% c("q23_s1", "q25_s2", "q37a_s3") ~ "nsrr_age",
      question %in% c("q23a_s1", "q25a_s2", "q37b_s3") ~ "nsrr_sex",
      question %in% c("q21_s1", "q22_s2", "q18_s3") ~ "nsrr_current_smoker",
      question %in% c("q24a_s1", "q26a_s2", "q38a_s3") ~ "height_feet",
      question %in% c("q24b_s1", "q26b_s2", "q38b_s3") ~ "height_inches",
      question %in% c("q25_s1", "q27_s2", "q39_s3") ~ "weight_lbs",
      TRUE ~ NA_character_
    )
  ) 


wide_mapped <- long_mapped |>
  select(wsc_id, nsrr_visit, measure, response) |>
  pivot_wider(names_from = measure, values_from = response) |> 
  mutate(wsc_vst = 0) |>
  rename(nsrrid = wsc_id) |>
  relocate(wsc_vst, .after = nsrr_visit)

no_responses <- wide_mapped|>
  filter(is.na(nsrr_age) & is.na(nsrr_sex) & is.na(height_feet) & is.na(height_inches) & is.na(weight_lbs) & is.na(nsrr_current_smoker))

nsrr_harmonized_survey <- wide_mapped |>
  anti_join(no_responses) |> 
  mutate(nsrr_age_gt89 = case_when(nsrr_age > 89  ~ "yes",
                                   nsrr_age <= 89 ~ "no",
                                   is.na(nsrr_age) ~ "not reported"),
         nsrr_sex = case_match(nsrr_sex, 
                                1 ~ "male",
                                2 ~ "female",
                                NA ~ "not reported"
                                ),
         nsrr_current_smoker = case_match(nsrr_current_smoker,
                                          1 ~ "yes",
                                          2 ~ "no",
                                          NA ~ "not reported"),
         nsrr_race = "not reported")|>
  mutate(height = height_feet*12 + height_inches,
         nsrr_bmi = 703 * weight_lbs / (height)^2 ) |>
  select(-c(height_feet, height_inches, height, weight_lbs))


wsc_harmonized.new <- wsc_harmonized |>
  mutate(nsrr_visit = as.character(nsrr_visit)) |>
  bind_rows(nsrr_harmonized_survey)|>
  arrange(nsrrid)


#harmonized dataset with added survey variables
write.csv(wsc_harmonized.new, file.path(releasepath, paste0(version, "/wsc-harmonized-dataset-", version, ".csv")), na = "", row.names = F)
