require 'rspec'

describe Deployment::Node do
  before(:each) do
    class Deployment::Process
      def log(mesage)
      end
    end
    class Deployment::Graph
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

  let(:task1_1) do
    Deployment::Task.new 'task1', node1
  end

  let(:task1_2) do
    Deployment::Task.new 'task2', node1
  end

  let(:task2_1) do
    Deployment::Task.new 'task1', node2
  end

  let(:task2_2) do
    Deployment::Task.new 'task2', node2
  end

  let(:process) do
    node1.graph.add_task task1_1
    node1.graph.add_task task1_2
    node2.graph.add_task task2_1
    node2.graph.add_task task2_2
    Deployment::Process[1, node1, node2]
  end

  subject { process }

  context '#attributes' do
    it 'have an id' do
      expect(subject.id).to eq 1
    end

    it 'can set an id' do
      subject.id = 2
      expect(subject.id).to eq 2
    end

    it 'have nodes' do
      expect(subject.nodes).to eq [node1, node2]
    end

    it 'can set nodes' do
      subject.nodes = [node1]
      expect(subject.nodes).to eq [node1]
    end

    it 'will set nodes only to the valid object' do
      expect do
        subject.nodes = 'node1'
      end.to raise_exception Deployment::InvalidArgument, /should be an array/
      expect do
        subject.nodes = ['node1']
      end.to raise_exception Deployment::InvalidArgument, /contain only Node/
    end
  end

  context  '#nodes processing' do
    it 'can iterate through all nodes' do
      expect(subject.each_node.to_a).to eq [node1, node2]
    end

    it 'can iterate through all tasks' do
      expect(subject.each_task.to_a).to eq [task1_1, task1_2, task2_1, task2_2]
    end

    it 'can check if all nodes are finished' do
      task1_1.status = :successful
      task1_2.status = :failed
      task2_1.status = :successful
      task2_2.status = :pending
      expect(subject.all_nodes_are_finished?).to eq false
      task2_2.status = :successful
      expect(subject.all_nodes_are_finished?).to eq true
    end

    it 'can check if all nodes are successful' do
      task1_1.status = :successful
      task1_2.status = :pending
      task2_1.status = :successful
      task2_2.status = :successful
      expect(subject.all_nodes_are_successful?).to eq false
      task1_2.status = :successful
      expect(subject.all_nodes_are_successful?).to eq true
    end

    it 'can check if some nodes are failed' do
      task1_1.status = :successful
      task1_2.status = :successful
      task2_1.status = :successful
      task2_2.status = :pending
      expect(subject.some_nodes_are_failed?).to eq false
      task2_2.status = :failed
      expect(subject.some_nodes_are_failed?).to eq true
    end
  end

  context '#inspection' do
    it 'can debug' do
      expect(subject).to receive(:log).with('Process[1]: message')
      subject.debug 'message'
    end

    it 'can log' do
      expect(subject).to respond_to :log
    end

    it 'can to_s' do
      expect(subject.to_s).to eq 'Process[1]'
    end

    it 'can inspect' do
      expect(subject.inspect).to eq 'Process[1] Nodes: node1, node2'
    end
  end
end
