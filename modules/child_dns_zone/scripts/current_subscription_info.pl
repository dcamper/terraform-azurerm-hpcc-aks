#!/usr/bin/perl
my $current_subscription_line = `az account list -o table|egrep " True"`; chomp $current_subscription_line;
my ($name, $cloud, $id, $tenant_id, $state, $IsDefault)=split(/\s+/,$current_subscription_line);
if ( ( $name =~ /^[\w\-]+$/ ) && ( $id =~ /^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/ ) ){
  print "{ \"name\" : \"$name\", \"id\" : \"$id\" }\n";
} else {
  print "FATAL ERROR: Could not get current subscription's name and id.\n";
  exit 1;
}
