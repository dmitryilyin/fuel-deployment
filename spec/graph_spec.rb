require 'rspec'

describe Deployment::Graph do
  before(:each) do
    class Deployment::Graph
      def log(mesage)
      end
    end
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

  let(:graph1) do
    Deployment::Graph.new node1
  end

  let(:graph2) do
    Deployment::Graph.new node2
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

  subject { graph1 }

  context '#attributes' do
    it 'should have a node' do
      expect(subject.node).to eq node1
      expect(subject.name).to eq node1.name
    end

    it 'should have a tasks' do
      expect(subject.tasks).to eq({})
    end

    it 'can set node only to a node object' do
      subject.node = node2
      expect(subject.node).to eq node2
      expect do
        subject.node = 'node3'
      end.to raise_error Deployment::InvalidArgument, /Not a node/
    end
  end

  context '#tasks' do
    it 'can create a new task' do
      subject.task_add_new 'new_task'
      expect(subject.tasks.values.first.name).to eq 'new_task'
      expect(subject.tasks.values.first.node.name).to eq 'node1'
    end

    it 'can add an existing task' do
      subject.task_add task1_1
      expect(subject.tasks.values.first.name).to eq 'task1'
      expect(subject.tasks.values.first.node.name).to eq 'node1'
    end

    it 'will add only tasks for this node' do
      expect do
        subject.task_add task2_1
      end.to raise_exception Deployment::InvalidArgument, /not for this node/
    end

    it 'can check if a task is present' do
      expect(subject.task_present? 'task1').to eq false
      subject.task_add task1_1
      expect(subject.task_present? 'task1').to eq true
      expect(subject.task_present? task1_1).to eq true
      expect(subject.task_present? task1_2).to eq false
    end

    it 'can get an existing task' do
      subject.task_add task1_1
      expect(subject.task_get 'task1').to eq task1_1
      expect(subject['task1']).to eq task1_1
      expect(subject.task_get task1_1).to eq task1_1
      expect(subject.task_get 'task2').to eq nil
    end

    it 'can remove a task' do
      subject.task_add task1_1
      expect(subject.tasks.values.first).to eq task1_1
      subject.task_remove task1_1
      expect(subject.tasks.values).to eq []
    end

    it 'can add dependencies between tasks of the same graph by name' do
      subject.task_add task1_1
      subject.task_add task1_2
      subject.dependency_add 'task1', 'task2'
      expect(subject['task2'].dependency_present? task1_1).to eq true
    end

    it 'will not add dependencies if there is no such task' do
      subject.task_add task1_1
      subject.task_add task1_2
      expect do
        subject.dependency_add 'task1', 'task3'
      end.to raise_exception Deployment::NoSuchTask, /no such task in the graph/
    end

    it 'can add dependencies between task objects of the same graph' do
      subject.task_add task1_1
      subject.task_add task1_2
      subject.dependency_add task1_1, task1_2
      expect(subject[task1_2].dependency_present? task1_1).to eq true
    end

    it 'can add dependencies between task objects in the different graphs' do
      graph1.task_add task1_1
      graph1.task_add task1_2
      graph2.task_add task2_1
      graph2.task_add task2_2
      subject.dependency_add task1_2, task2_2
      expect(graph2[task2_2].dependency_present? task1_2).to eq true
    end

    it 'can iterate through tasks' do
      subject.task_add task1_1
      subject.task_add task1_2
      expect(subject.each.to_a).to eq [task1_1, task1_2]
    end
  end

  context '#tasks advanced' do
    it 'can determine that all tasks are finished' do
      expect(subject.tasks_are_finished?).to eq true
      subject.task_add task1_1
      subject.task_add task1_2
      expect(subject.tasks_are_finished?).to eq false
      task1_1.status = :successful
      task1_2.status = :failed
      subject.reset
      expect(subject.tasks_are_finished?).to eq true
    end

    it 'can determine that all tasks are successful' do
      expect(subject.tasks_are_successful?).to eq true
      subject.task_add task1_1
      subject.task_add task1_2
      expect(subject.tasks_are_successful?).to eq false
      task1_1.status = :successful
      task1_2.status = :successful
      subject.reset
      expect(subject.tasks_are_successful?).to eq true
    end

    it 'can determine that some tasks are failed' do
      expect(subject.tasks_have_failed?).to eq false
      subject.task_add task1_1
      subject.task_add task1_2
      expect(subject.tasks_have_failed?).to eq false
      task1_1.status = :successful
      task1_2.status = :failed
      subject.reset
      expect(subject.tasks_have_failed?).to eq true
    end

    it 'can get a runnable task' do
      expect(subject.ready_task).to be_nil
      subject.task_add task1_1
      expect(subject.ready_task).to eq task1_1
      task1_1.status = :failed
      expect(subject.ready_task).to be_nil
    end

    it 'uses task dependencies to determine a runnable task' do
      subject.task_add task1_1
      subject.task_add task1_2
      subject.dependency_add task1_1, task1_2
      expect(subject.ready_task).to eq task1_1
      task1_1.status = :successful
      expect(subject.ready_task).to eq task1_2
      task1_1.status = :failed
      expect(subject.ready_task).to be_nil
    end
  end

  context '#inspections' do
    it 'can debug' do
      expect(subject).to receive(:log).with('Graph[node1]: message')
      subject.debug 'message'
    end

    it 'can log' do
      expect(subject).to respond_to :log
    end

    it 'can to_s' do
      expect(subject.to_s).to eq 'Graph[node1]'
    end

    it 'can inspect' do
      expect(subject.inspect).to eq 'Graph[node1] Tasks: 0 Finished: true Failed: false Successful: true'
      subject.task_add task1_1
      expect(subject.inspect).to eq 'Graph[node1] Tasks: 1 Finished: false Failed: false Successful: false'
      task1_1.status = :successful
      subject.reset
      expect(subject.inspect).to eq 'Graph[node1] Tasks: 1 Finished: true Failed: false Successful: true'
      task1_1.status = :failed
      subject.reset
      expect(subject.inspect).to eq 'Graph[node1] Tasks: 1 Finished: true Failed: true Successful: false'
    end
  end
end
