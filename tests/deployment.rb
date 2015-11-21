require File.absolute_path File.join File.dirname(__FILE__), 'test_node.rb'

PLOT = false
FAIL = true

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

class Deployment::PlotProcess < Deployment::Process
  # loop once through all nodes and process them
  def process_all_nodes
    debug 'Start processing all nodes'
    each_node do |node|
      process_node node
      gv_load
      gv_make_step_image
    end
  end
end

class Deployment::TestNodeWithFail < Deployment::TestNode
  def poll
    debug 'Poll node status'
    if busy?
      status = :successful
      status = :failed if task.name == 'task4' and node.name == 'node2'
      debug "#{task} finished with: #{status}"
      self.task.status = status
      self.status = :online
    end
  end
end

if FAIL
  node1 = Deployment::TestNodeWithFail.new 'node1'
  node2 = Deployment::TestNodeWithFail.new 'node2'
else
  node1 = Deployment::TestNode.new 'node1'
  node2 = Deployment::TestNode.new 'node2'
end

node1_data.each do |task_from, task_to|
  task_from = node1.graph.create_task "task#{task_from}"
  task_to = node1.graph.create_task "task#{task_to}"
  node1.graph.add_dependency task_from, task_to
end

node2_data.each do |task_from, task_to|
  task_from = node2.graph.create_task "task#{task_from}"
  task_to = node2.graph.create_task "task#{task_to}"
  node2.graph.add_dependency task_from, task_to
end

node2['task4'].depends node1['task3']
node2['task5'].depends node1['task13']
node1['task15'].depends node2['task6']

if PLOT
  deployment = Deployment::PlotProcess.new(node1, node2)
else
  deployment = Deployment::Process.new(node1, node2)
end

deployment.id = 'deployment'

if PLOT
  deployment.gv_load
  deployment.gv_make_image
end

deployment.run
