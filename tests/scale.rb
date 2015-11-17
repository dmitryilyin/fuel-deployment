lib_dir = File.join File.dirname(__FILE__), '../lib/'
lib_dir = File.absolute_path File.expand_path lib_dir
$LOAD_PATH << lib_dir

require 'task'
require 'node'
require 'error'
require 'graph'
require 'process'

TASK_NUMBER = 100
NODE_NUMBER = 10
PLOT = true

def make_nodes
  1.upto(NODE_NUMBER).map do |node|
    node = Deployment::Node.new "node#{node}"
    make_tasks node
    node
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
    node.graph.dependency_add task_from, task_to
    previous_task = task
  end
end

def make_deployment
  Deployment::Process[2, *make_nodes]
end

deployment = make_deployment

puts 'Graphs generated'

if PLOT

  begin
    require 'graphviz'
  rescue LoadError
    nil
  end

  if defined? GraphViz
    deployment.gv_load
    deployment.gv_make_image
  end

end

deployment.run
