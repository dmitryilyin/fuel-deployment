#!/usr/bin/env ruby
require File.absolute_path File.join File.dirname(__FILE__), 'test_node.rb'

node1 = Deployment::TestNode.new 'node1'
node2 = Deployment::TestNode.new 'node2'
node3 = Deployment::TestNode.new 'node3'
node4 = Deployment::TestNode.new 'node4'
node5 = Deployment::TestNode.new 'node5'

node1.add_new_task('task1')
node1.add_new_task('final')

node2.add_new_task('task1')
node2.add_new_task('final')

node3.add_new_task('task1')
node3.add_new_task('final')

node4.add_new_task('task1')
node4.add_new_task('final')

node5.add_new_task('task1')
node5.add_new_task('final')

node1['final'].after node1['task1']
node2['final'].after node2['task1']
node3['final'].after node3['task1']
node4['final'].after node4['task1']
node5['final'].after node5['task1']

if options[:plot]
  deployment = Deployment::PlotProcess[node1, node2, node3, node4, node5]
else
  deployment = Deployment::Process[node1, node2, node3, node4, node5]
end

deployment.id = 'concurrency'

node1['task1'].maximum_concurrency = 2
node1['final'].maximum_concurrency = 1

if options[:plot]
  deployment.gv_make_image
end

if options[:interactive]
  binding.pry
else
  deployment.run
end
