#
# Cookbook Name:: helloworld
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved
#

cookbook_file "/root/helloworld" do
  source "helloworld"
  mode 0755
  owner "root"
  group "root"
end
