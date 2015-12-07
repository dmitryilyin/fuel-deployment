#!/usr/bin/env ruby
require File.absolute_path File.join File.dirname(__FILE__), 'test_node.rb'
Deployment::Log.logger.level = Logger::DEBUG

node1 = Deployment::TestNode.new 'node1'

task1 = node1.graph.add_new_task 'task1'
task2 = node1.graph.add_new_task 'task2'
task3 = node1.graph.add_new_task 'task3'
# task4 = node1.graph.add_new_task 'task4'
# task5 = node1.graph.add_new_task 'task5'
# task6 = node1.graph.add_new_task 'task6'
# task7 = node1.graph.add_new_task 'task7'
#
# task2.after task1
# task3.after task1
# task4.after task2
# task5.after task2
# task6.after task3
# task7.after task3
# task5.before task6

# task2.after task1
# task3.after task2
# task4.after task2
# task5.after task3
# task6.after task4
# task7.after task5
# task7.after task6

task2.after task1
task3.after task2
task1.after task3

deployment = Deployment::Process[node1]
deployment.id = 'loop'

if options[:interactive]
  binding.pry
else
  deployment.run
end
