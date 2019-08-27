#!/bin/perl


print qq[

unload to $ARGV[0]_cc.unl
select
chain,config_level,affiliates,properties,cache_keys,noncache_keys,cache_neg_rates,force_cache_only 
from ud_cache_chain_config where chain = '$ARGV[0]' and affiliates like '%GT%'
union
select
chain,config_level,affiliates,properties,cache_keys,noncache_keys,cache_neg_rates,force_cache_only 
from ud_cache_chain_config where chain = '$ARGV[0]' and affiliates like '%OT%'
union
select
chain,config_level,affiliates,properties,cache_keys,noncache_keys,cache_neg_rates,force_cache_only 
from ud_cache_chain_config where chain = '$ARGV[0]' and config_level=0;

unload to $ARGV[0]_stl.unl
select 
chain,config_level,affiliates,properties,min_lead_days,max_lead_days,cache_stale_time_value,cache_stale_time_units 
from ud_cache_stale_time_config where chain = '$ARGV[0]' and config_level = 0 
union
select 
chain,config_level,affiliates,properties,min_lead_days,max_lead_days,cache_stale_time_value,cache_stale_time_units 
from ud_cache_stale_time_config where chain = '$ARGV[0]' and affiliates like '%GT%'
union
select 
chain,config_level,affiliates,properties,min_lead_days,max_lead_days,cache_stale_time_value,cache_stale_time_units 
from ud_cache_stale_time_config where chain = '$ARGV[0]' and affiliates like '%OT%' order by config_level,min_lead_days;
    ] . "\n";
exit 0;
