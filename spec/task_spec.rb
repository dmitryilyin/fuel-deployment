require 'spec_helper'

describe Deployment::Task do

  let(:node1) do
    Deployment::Node.new 'node1'
  end

  let(:node2) do
    Deployment::Node.new 'node2'
  end

  let(:task1) do
    Deployment::Task.new 'task1', node1
  end

  let(:task2) do
    Deployment::Task.new 'task2', node1
  end

  let(:task3) do
    Deployment::Task.new 'task3', node1
  end

  let(:task2_1) do
    Deployment::Task.new 'task1', node2
  end

  let(:task2_2) do
    Deployment::Task.new 'task2', node2
  end

  subject { task1 }

  context '#attributes' do
    it 'should have a name' do
      expect(subject.name).to eq 'task1'
    end

    it 'should have a node' do
      expect(subject.node).to eq node1
    end

    it 'should have a status' do
      expect(subject.status).to eq :pending
    end

    it 'should have a required' do
      expect(subject.backward_dependencies).to eq Set.new
    end

    it 'should have a data' do
      expect(subject.data).to eq nil
    end

    it 'should set name as a string' do
      subject.name = 'task3'
      expect(subject.name).to eq 'task3'
      subject.name = 1
      expect(subject.name).to eq '1'
    end

    it 'should set node only to a node object' do
      subject.node = node2
      expect(subject.node).to eq node2
      expect do
        subject.node = 'node3'
      end.to raise_error Deployment::InvalidArgument, /Not a node/
    end

    it 'should set only a correct status' do
      subject.status = :successful
      expect(subject.status).to eq :successful
      subject.status = 'failed'
      expect(subject.status).to eq :failed
      expect do
        subject.status = 'ready'
      end.to raise_exception Deployment::InvalidArgument, /Invalid task status/
    end

    it 'can set data' do
      subject.data = 'my data'
      expect(subject.data).to eq 'my data'
    end

    it 'can use dynamic status setters' do
      subject.set_status_failed
      expect(subject.status).to eq :failed
    end
  end

  context '#dependencies basic' do
    it 'can add a backward dependency task' do
      subject.dependency_backward_add task2
      expect(subject.backward_dependencies).to eq Set[task2]
    end

    it 'can add a forward dependency task' do
      subject.dependency_forward_add task2
      expect(subject.forward_dependencies).to eq Set[task2]
    end

    it 'can only add tasks as backward dependencies' do
      expect do
        subject.dependency_backward_add 'dep1'
      end.to raise_error Deployment::InvalidArgument, /should be a task/
    end

    it 'can only add tasks as forward dependencies' do
      expect do
        subject.dependency_forward_add 'dep1'
      end.to raise_error Deployment::InvalidArgument, /should be a task/
    end

    it 'can determine if there are backward dependencies' do
      expect(subject.dependency_backward_any?).to eq false
      subject.dependency_backward_add task2
      expect(subject.dependency_backward_any?).to eq true
    end

    it 'can determine if there are forward dependencies' do
      expect(subject.dependency_forward_any?).to eq false
      subject.dependency_forward_add task2
      expect(subject.dependency_forward_any?).to eq true
    end

    it 'can remove a forward dependency' do
      subject.dependency_backward_add task2
      expect(subject.backward_dependencies).to eq Set[task2]
      subject.dependency_backward_remove task2
      expect(subject.backward_dependencies).to eq Set.new
    end

    it 'can remove a backward dependency' do
      subject.dependency_forward_add task2
      expect(subject.forward_dependencies).to eq Set[task2]
      subject.dependency_forward_remove task2
      expect(subject.forward_dependencies).to eq Set.new
    end

    it 'can check if a task has the specific backward dependency' do
      expect(subject.dependency_backward_present? task2).to eq false
      subject.dependency_backward_add task2
      expect(subject.dependency_backward_present? task2).to eq true
      expect(subject.dependency_backward_present? task3).to eq false
    end

    it 'can check if a task has the specific forward dependency' do
      expect(subject.dependency_forward_present? task2).to eq false
      subject.dependency_forward_add task2
      expect(subject.dependency_forward_present? task2).to eq true
      expect(subject.dependency_forward_present? task3).to eq false
    end

    it 'can iterate through backward dependencies' do
      subject.dependency_backward_add task2
      dependencies = subject.each_backward_dependency.to_a
      expect(dependencies).to eq [task2]
    end

    it 'can iterate through forward dependencies' do
      subject.dependency_forward_add task2
      dependencies = subject.each_forward_dependency.to_a
      expect(dependencies).to eq [task2]
    end

    it 'defaults all actions to the backward dependencies' do
      actions = {
          :dependency_add => :dependency_backward_add,
          :dependency_remove => :dependency_backward_remove,
          :dependency_present? => :dependency_backward_present?,
          :dependency_any? => :dependency_backward_any?,
          :each => :each_backward_dependency,
      }
      actions.each do |method_alias, method_name|
        expect(subject.method method_alias).to eq subject.method method_name
      end
    end
  end

  context '#dependencies advanced' do
    it 'dependencies are met if there are no dependencies' do
      expect(task1.dependency_backward_any?).to eq false
      expect(task1.dependencies_are_ready?).to eq true
    end

    it 'there are no dependency errors if there are no dependencies' do
      expect(task1.dependency_backward_any?).to eq false
      expect(task1.dependencies_have_failed?).to eq false
    end

    it 'can detect that task is ready to run by its status' do
      expect(task1.ready?).to eq true
      task1.status = :successful
      expect(task1.ready?).to eq false
      task1.status = :skipped
      expect(task1.ready?).to eq false
      task1.status = :failed
      expect(task1.ready?).to eq false
    end

    it 'can detect different task statuses' do
      task1.status = :pending
      expect(task1.pending?).to eq true
      task1.status = :successful
      expect(task1.successful?).to eq true
      task1.status = :skipped
      expect(task1.skipped?).to eq true
      task1.status = :running
      expect(task1.running?).to eq true
      task1.status = :failed
      expect(task1.failed?).to eq true
    end

    it 'can detect that task is ready by dependencies' do
      task1.dependency_backward_add task2
      expect(task1.dependencies_are_ready?).to eq false
      expect(task1.ready?).to eq false
      task2.status = :successful
      expect(task1.dependencies_are_ready?).to eq true
      expect(task1.ready?).to eq true
      task1.dependency_backward_add task3
      expect(task1.dependencies_are_ready?).to eq false
      expect(task1.ready?).to eq false
    end

    it 'can detect that direct dependencies are failed' do
      task1.dependency_backward_add task2
      expect(task1.dependencies_have_failed?).to eq false
      expect(task2.dependencies_have_failed?).to eq false
      expect(task1.failed?).to eq false
      expect(task2.failed?).to eq false
      task2.status = :failed
      expect(task1.dependencies_have_failed?).to eq true
      expect(task1.failed?).to eq true
      expect(task2.dependencies_have_failed?).to eq false
      expect(task2.failed?).to eq true
    end

    it 'can detect that far dependencies are failed' do
      task1.dependency_backward_add task2
      task2.dependency_backward_add task3
      expect(task1.dependencies_have_failed?).to eq false
      expect(task1.failed?).to eq false
      expect(task2.dependencies_have_failed?).to eq false
      expect(task2.failed?).to eq false
      expect(task3.dependencies_have_failed?).to eq false
      expect(task3.failed?).to eq false
      task3.status = :failed
      expect(task1.dependencies_have_failed?).to eq true
      expect(task1.failed?).to eq true
      expect(task2.dependencies_have_failed?).to eq true
      expect(task2.failed?).to eq true
      expect(task3.dependencies_have_failed?).to eq false
      expect(task3.failed?).to eq true
    end

    it 'can reset saved detections' do
      task1.dependency_backward_add task2
      task2.status = :failed
      expect(task1.failed?).to eq true
      task2.status = :pending
      task1.reset
      expect(task1.failed?).to eq false
    end

  end

  context '#inspection' do

    it 'can to_s' do
      expect(subject.to_s).to eq 'Task[node1/task1]'
    end

    it 'can inspect' do
      expect(subject.inspect).to eq 'Task[node1/task1] Status: pending DepsReady: true DepsFailed: false'
      subject.status = :failed
      expect(subject.inspect).to eq 'Task[node1/task1] Status: failed DepsReady: true DepsFailed: false'
      subject.dependency_backward_add task2
      expect(subject.inspect).to eq 'Task[node1/task1] Status: failed DepsReady: false DepsFailed: false After: Task[node1/task2]'
      subject.dependency_backward_add task2_1
      expect(subject.inspect).to eq 'Task[node1/task1] Status: failed DepsReady: false DepsFailed: false After: Task[node1/task2], Task[node2/task1]'
      subject.dependency_forward_add task2_2
      expect(subject.inspect).to eq 'Task[node1/task1] Status: failed DepsReady: false DepsFailed: false After: Task[node1/task2], Task[node2/task1] Before: Task[node2/task2]'
    end
  end

  context '#concurrency' do
    it 'has maximum_concurrency' do
      expect(subject.maximum_concurrency).to eq 0
    end

    it 'can set maximum_concurrency' do
      subject.maximum_concurrency = 1
      expect(subject.maximum_concurrency).to eq 1
      subject.maximum_concurrency = '2'
      expect(subject.maximum_concurrency).to eq 2
      expect do
        subject.maximum_concurrency = 'value'
      end.to raise_exception Deployment::InvalidArgument, /should be an integer/
    end

    it 'can read the current concurrency counter' do
      expect(subject.current_concurrency).to eq 0
    end

    it 'can increase the current concurrency counter' do
      subject.current_concurrency_reset
      expect(subject.current_concurrency_increase).to eq 1
      expect(subject.current_concurrency).to eq 1
      subject.current_concurrency_increase
      expect(subject.current_concurrency).to eq 2
    end

    it 'can decrease the current concurrency counter' do
      subject.current_concurrency_reset
      subject.current_concurrency_increase
      expect(subject.current_concurrency).to eq 1
      expect(subject.current_concurrency_decrease).to eq 0
      expect(subject.current_concurrency).to eq 0
      expect(subject.current_concurrency_decrease).to eq 0
      expect(subject.current_concurrency).to eq 0
    end

    it 'can manually set the current concurrency value' do
      subject.current_concurrency_reset
      expect(subject.current_concurrency = 100).to eq 100
      expect(subject.current_concurrency).to eq 100
      expect(subject.current_concurrency = -100).to eq -100
      expect(subject.current_concurrency).to eq 0
    end

    it 'can reset the current concurrency' do
      subject.current_concurrency_reset
      subject.current_concurrency_increase
      expect(subject.current_concurrency).to eq 1
      expect(subject.current_concurrency_reset).to eq 0
      expect(subject.current_concurrency).to eq 0
    end

    it 'can check that the concurrency is available' do
      subject.current_concurrency_reset
      expect(subject.concurrency_available?).to eq true
      subject.maximum_concurrency = 1
      expect(subject.concurrency_available?).to eq true
      subject.current_concurrency_increase
      expect(subject.concurrency_available?).to eq false
      subject.current_concurrency_decrease
      expect(subject.concurrency_available?).to eq true
      subject.current_concurrency_increase
      expect(subject.concurrency_available?).to eq false
      subject.maximum_concurrency = 2
      expect(subject.concurrency_available?).to eq true
    end

    it 'can change the current concurrency when the status changes for all nodes' do
      task1.current_concurrency_reset
      task1.maximum_concurrency = 1
      task1.status = :running
      expect(task1.current_concurrency).to eq 1
      expect(task2_1.current_concurrency).to eq 1
      expect(task2_2.current_concurrency).to eq 0
      task1.status = :successful
      expect(task1.current_concurrency).to eq 0
      expect(task2_1.current_concurrency).to eq 0
      expect(task2_2.current_concurrency).to eq 0
    end
  end

  context '#run' do
    it 'can run the task on the node' do
      expect(node1).to receive(:run).with(task1)
      task1.run
    end

  end

end
