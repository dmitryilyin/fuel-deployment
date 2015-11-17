require 'spec_helper'

describe Deployment::Task do
  before(:each) do
    class Deployment::Task
      def log(mesage)
      end
    end
  end

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
      expect(subject.required).to eq Set.new
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

    it 'can use dynamic status setters' do
      subject.set_status_failed
      expect(subject.status).to eq :failed
    end
  end

  context '#dependencies basic' do
    it 'can add a dependency task' do
      subject.dependency_add task2
      expect(subject.required).to eq Set[task2]
    end

    it 'can only add tasks as dependencies' do
      expect do
        subject.dependency_add 'dep1'
      end.to raise_error Deployment::InvalidArgument, /should be a task/
    end

    it 'can determine if there are dependencies' do
      expect(subject.dependencies_any?).to eq false
      subject.dependency_add task2
      expect(subject.dependencies_any?).to eq true
    end

    it 'can remove a dependency' do
      subject.dependency_add task2
      expect(subject.required).to eq Set[task2]
      subject.dependency_remove task2
      expect(subject.required).to eq Set.new
    end

    it 'can check if a task has the specific dependency' do
      expect(subject.dependency_present? task2).to eq false
      subject.dependency_add task2
      expect(subject.dependency_present? task2).to eq true
      expect(subject.dependency_present? task3).to eq false
    end

    it 'can iterate through dependencies' do
      subject.dependency_add task2
      dependencies = subject.each_dependency.to_a
      expect(dependencies).to eq [task2]
    end
  end

  context '#dependencies advanced' do
    it 'dependencies are met if there are no dependencies' do
      expect(task1.dependencies_any?).to eq false
      expect(task1.dependencies_are_ready?).to eq true
    end

    it 'there are no dependency errors if there are no dependencies' do
      expect(task1.dependencies_any?).to eq false
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
      task1.dependency_add task2
      expect(task1.dependencies_are_ready?).to eq false
      expect(task1.ready?).to eq false
      task2.status = :successful
      expect(task1.dependencies_are_ready?).to eq true
      expect(task1.ready?).to eq true
      task1.dependency_add task3
      expect(task1.dependencies_are_ready?).to eq false
      expect(task1.ready?).to eq false
    end

    it 'can detect that direct dependencies are failed' do
      task1.dependency_add task2
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
      task1.dependency_add task2
      task2.dependency_add task3
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
      task1.dependency_add task2
      task2.status = :failed
      expect(task1.failed?).to eq true
      task2.status = :pending
      task1.reset
      expect(task1.failed?).to eq false
    end

  end

  context '#inspection' do
    it 'can debug' do
      expect(subject).to receive(:log).with('Task[task1]: message')
      subject.debug 'message'
    end

    it 'can log' do
      expect(subject).to respond_to :log
    end

    it 'can to_s' do
      expect(subject.to_s).to eq 'Task[task1]'
    end

    it 'can inspect' do
      expect(subject.inspect).to eq 'Task[task1] Status: pending'
      subject.status = :failed
      expect(subject.inspect).to eq 'Task[task1] Status: failed'
      subject.dependency_add task2
      expect(subject.inspect).to eq 'Task[task1] Status: failed Required: task2(node1)'
      subject.dependency_add task2_1
      expect(subject.inspect).to eq 'Task[task1] Status: failed Required: task2(node1), task1(node2)'
    end
  end

  context '#run' do
    it 'can run the task on the node' do
      expect(node1).to receive(:run).with(task1)
      task1.run
    end

  end

end
