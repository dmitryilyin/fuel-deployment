#!/usr/bin/env ruby
require File.absolute_path File.join File.dirname(__FILE__), 'test_node.rb'
require 'yaml'

deployment_tasks = YAML.load_file File.join File.dirname(__FILE__), 'fuel.yaml'

nodes = deployment_tasks.keys.inject({}) do |nodes, node_id|
  node = Deployment::TestNode.new(node_id)
  nodes.merge(node_id => node)
end

deployment_tasks.each do |node_id, node_tasks|
  node_tasks.each do |task_data|
    nodes[node_id].graph.create_task task_data['id'], task_data
  end
end

deployment_tasks.each do |node_id, node_tasks|
  node_tasks.each do |task_data|
    task = nodes[node_id][task_data['id']]

    requires = task_data.fetch 'requires', []
    requires.each do |requirement|
      next unless requirement.is_a? Hash
      required_task = nodes[requirement['node_id']][requirement['name']]
      unless required_task
        warn "Task: #{requirement['name']} is not found on node: #{nodes[requirement['node_id']]}"
        next
      end
      task.requires required_task
    end

    required_for = task_data.fetch 'required_for', []
    required_for.each do |requirement|
      next unless requirement.is_a? Hash
      required_by_task = nodes[requirement['node_id']][requirement['name']]
      task = nodes[node_id][task_data['id']]
      unless required_by_task
        warn "Task: #{requirement['name']} is not found on node: #{nodes[requirement['node_id']]}"
        next
      end
      task.is_required required_by_task
    end
  end
end

deployment = Deployment::Process.new nodes.values
deployment.id = 'fuel'

if options[:interactive]
  binding.pry
else
  deployment.run
end
