lib_dir = File.join File.dirname(__FILE__), '../lib/'
lib_dir = File.absolute_path File.expand_path lib_dir
$LOAD_PATH << lib_dir

require 'task'
require 'node'
require 'error'
require 'graph'
require 'process'

node1_data = [
    [0, 1],
    [1, 2],
    [1, 3],
    [2, 4],
    [2, 5],
    [3, 6],
    [3, 7],
    [4, 8],
    [5, 10],
    [6, 11],
    [7, 12],
    [8, 9],
    [10, 9],
    [11, 13],
    [12, 13],
    [13, 9],
    [9, 14],
    [14, 15],
]

node2_data = [
    [0, 1],
    [1, 2],
    [0, 3],
    [3, 4],
    [4, 5],
    [5, 6],
    [5, 7],
    [6, 8],
]

node1 = Deployment::Node.new 'node1'
node2 = Deployment::Node.new 'node2'

node1_data.each do |task_from, task_to|
  task_from = node1.graph.create_task "task#{task_from}"
  task_to = node1.graph.create_task "task#{task_to}"
  node1.graph.dependency_add task_from, task_to
end

node2_data.each do |task_from, task_to|
  task_from = node2.graph.create_task "task#{task_from}"
  task_to = node2.graph.create_task "task#{task_to}"
  node2.graph.dependency_add task_from, task_to
end

node2['task4'].depends node1['task3']
node2['task5'].depends node1['task13']
node1['task15'].depends node2['task6']

deployment = Deployment::Process[1, node1, node2]

begin
    require 'graphviz'
rescue LoadError
  nil
end

if defined? GraphViz
  deployment.gv_load
  deployment.gv_make_image
end

deployment.run
