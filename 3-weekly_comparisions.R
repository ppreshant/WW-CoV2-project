# Loading libraries ----

# Loading libraries, functions and user inputs
source('./general_functions.R') # Source the general_functions file
source('./inputs_for_analysis.R') # Source the file with user inputs

# sheets to read from "qPCR data to present + recoveries"" google sheet
read_these_sheets <- c('622 Rice', '629 Rice', '706 Rice', '713 Rice', '720 Rice', '727 Rice', '803 Rice', '810 Rice', '817 Rice', '824 Rice', '831 Rice', '907 Rice', '914 Rice', '928 Rice', '1005 Rice', '1012 Rice', '1019 Rice', '1026 Rice', '1102 Rice', '1109 Rice', '1116 Rice') # sheet name(s) in the raw data file (qPCR data dump) - Separate by comma (,)

# read_these_sheets <- c('810 Rice', '817 Rice', '824 Rice', '831 Rice', '907 Rice', '915 Rice') # sheet name(s) in the raw data file (qPCR data dump) - Separate by comma (,)
title_name <- 'Weekly till 1116' # name of the filename for writing presentable data and plot title

# file for metadata - flow rate litres/day; population by WWTP area
meta_file <- 'WWTP_All_Results' %>% str_c('../../../Covid Tracking Project/Rice and Baylor Combined Data/', ., '.csv')

# Extra categories to exclude from plotting (separate by | like this 'Vaccine|Troubleshooting')
extra_categories = 'Std|Vaccine|Control|Water|NTC|TR|Blank'


# Data input ----


# Read the flow rates and population numbers from Kathy's files
metadata <- read_csv(meta_file, col_types = 'cccccicciid') %>% select(WWTP, Date, Population, Flow.Rate.Liters.Per.Day) %>% 
  unique() %>%  
  
  mutate('Week' = Date %>% as.character() %>% str_match('^(.*)/(.*)/.*') %>% 
           {if_else( str_detect(.[,3], '[:digit:]{2}'), str_c(.[,2], .[,3]), 
                     str_c(.[,2], .[,3], sep = '0')) } ) %>% 
  select(-Date)

# Acquire all the pieces of the data : read saved raw qPCR results from a google sheet
list_rawqpcr <- map(read_these_sheets, ~ read_sheet(sheeturls$complete_data , sheet = .x) %>%  
                      mutate('Week' = str_match(.x, '[:digit:]*(?= Rice)')) %>%
                      
                      # backward compatibility (accounting for column name changes)
                      rename('Target' = matches('Target'), 
                             'Received_WW_vol' = matches('WW_vol|Original Sample Volume'), # if both old and new names are present, it will throw error
                             'Percentage_recovery_BCoV' = matches('Recovery fraction'),
                             'Ct' = matches('^CT', ignore.case = T)) %>% 
                      
                      mutate_at('Target', ~str_replace_all(., c('.*N1.*' = 'SARS CoV-2 N1', '.*N2.*' = 'SARS CoV-2 N2')))
                    
) 

rawqpcr <- bind_rows(list_rawqpcr) # bind all the sheets' results into 1 data frame/tibble

results_abs <- rawqpcr %>% filter(!str_detect(Facility, extra_categories)) %>%  # remove unnecessary data
  filter(!str_detect(Target, 'BRSV')) %>% 
  left_join(metadata) %>% 
  mutate_at('Week', ~ as_factor(.)) %>% 
  mutate('Viral load per capita per day' = `Copies/l WW` * Flow.Rate.Liters.Per.Day / Population)


# Plots to html ----

# calling r markdown file
rmarkdown::render('3.1-weekly_comparison plots.rmd', output_file = str_c('./qPCR analysis/Weekly ', title_name, '.html'))

