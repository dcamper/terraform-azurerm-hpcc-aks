#!/usr/bin/perl
$/="";
$_ = <STDIN>;
#print "DEBUG: All input from STDIN: \"$_\"\n";
@assignstatement = split(/,/,$_);

# Foreach assignment statement get the variable, key, and its value. Make HASH, %assign
%assign=();
foreach (@assignstatement){
   next if /^\s*$/ || /^[\{\}]\s*$/ || /^\s*#/;
   my ($key, $value)=split(/\s*[=:]\s*/,$_);
   $key =~ s/[{}"\n\s]+//g;
   $value =~ s/[{}"\n]//g;
   $value =~ s/\s+$//;
   #print "DEBUG: key=\"$key\", value=\"$value\"\n";
   $assign{$key} = ( $value =~ /^\s*$/ )? '' : $value;
}

$parent_subscription = $assign{parent_subscription};
$child_dns_name_prefix = $assign{child_dns_name_prefix};
$hpcc_resource_group = $assign{hpcc_resource_group};

#print "DEBUG: parent_subscription=\"$parent_subscription\", child_dns_name_prefix=\"$child_dns_name_prefix\", hpcc_resource_group=\"$hpcc_resource_group\"\n";

#print "DEBUG: az network dns zone list\n\n";
$parent_ids = `az network dns zone list 2>&1`;
@parent_id = split(/\n/,$parent_ids);
($parent_id) = grep(/\"id\":.*\/dnszones\/$parent_subscription/,@parent_id);
#print "DEBUG: parent_id=\"$parent_id\"\n\n";
$parent_rg = ($parent_id =~ /resourceGroups\/([^\/]+)/)? $1 : "";
#print "DEBUG: parent_rg=\"$parent_rg\"\n";
$parent_dnszone = ($parent_id =~ /dnszones\/($parent_subscription[^"]+)/)? $1 : "";
#print "DEBUG: parent_dnszone=\"$parent_dnszone\"\n";

if ( ($parent_id !~ /$parent_subscription/) || ($parent_rg eq "") || ($parent_dnszone eq "") ){
  die "FATAL ERROR: Could not find parent dns zone for subscription\"$parent_subscription\"\n";
}

$child_dns_name = "$child_dns_name_prefix.$parent_dnszone";

$rc = `az network dns zone create -g $parent_rg -n $child_dns_name -p $parent_dnszone 2>&1`;
#print "DEBUG: rc=\"$rc\"\n";
if ( $rc !~ /$child_dns_name/ ){
  die "FATAL ERROR: Could not create child dns zone, $child_dns_name , for subscription\"$parent_subscription\"\n";
}

print "{\"child_dns_name\" : \"$child_dns_name\", \"child_dns_resource_group\" : \"$parent_rg\"}\n";
