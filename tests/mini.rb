#!/usr/bin/env ruby
require File.absolute_path File.join File.dirname(__FILE__), 'test_node.rb'

PLOT = ARGV[0] == '1'

node1 = Deployment::TestNode.new 'node1'

node1.graph.add_new_task 'task1'
node1.graph.add_new_task 'task2'
node1.graph.add_new_task 'task3'

node1['task1'].before node1['task2']
node1['task2'].before node1['task3']

deployment = Deployment::Process[node1]
deployment.id = 'mini'

if PLOT
  deployment.gv_load
  deployment.gv_make_image
end

deployment.run

