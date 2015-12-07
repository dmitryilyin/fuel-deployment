#!/usr/bin/env ruby
require File.absolute_path File.join File.dirname(__FILE__), 'test_node.rb'

TASK_NUMBER = 100
NODE_NUMBER = 100

Deployment::Log.logger.level = Logger::WARN

def make_nodes
  1.upto(NODE_NUMBER).map do |node|
    Deployment::TestNode.new "node#{node}"
  end
end

def make_tasks(node)
  previous_task = nil
  1.upto(TASK_NUMBER).each do |number|
    task = "task#{number}"
    unless previous_task
      previous_task = task
      next
    end
    task_from = node.graph.create_task previous_task
    task_to = node.graph.create_task task
    node.graph.add_dependency task_from, task_to
    previous_task = task
  end
end

nodes = make_nodes

nodes.each do |node|
  puts "Make tasks for: #{node}"
  make_tasks node
  nil
end

nodes.each do |node|
  next if node == nodes.first
  node['task10'].depends nodes.first['task50']
end

deployment = Deployment::Process[*nodes]
deployment.id = 'scale'

if options[:plot]
  deployment.gv_make_image
end

if options[:interactive]
  binding.pry
else
  deployment.run
end
