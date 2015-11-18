require 'log'

module Deployment
  class Node
    ALLOWED_STATUSES = [:online, :busy, :offline, :failed, :successful]

    def initialize(name, id = nil)
      @name = name
      @status = :online
      @task = nil
      @id = id || self.name
      create_new_graph
    end

    include Enumerable
    include Deployment::Log

    attr_reader :status
    attr_reader :name
    attr_reader :task
    attr_reader :graph
    attr_accessor :id

    def status=(value)
      value = value.to_sym
      fail Deployment::InvalidArgument, "#{self}: Invalid node status: #{value}" unless ALLOWED_STATUSES.include? value
      @status = value
    end

    def finished?
      [:failed, :successful?].include? status or tasks_are_finished?
    end

    def online?
      status == :online
    end

    def busy?
      status == :busy
    end

    def offline?
      status == :offline
    end

    def failed?
      status == :failed or tasks_have_failed?
    end

    def successful?
      status == :successful? or tasks_are_successful?
    end

    ALLOWED_STATUSES.each do |status|
      method_name = "set_status_#{status}".to_sym
      define_method(method_name) do
        self.status = status
      end
    end

    def name=(name)
      @name = name.to_s
    end

    def task=(task)
      unless task.nil?
        fail Deployment::InvalidArgument, "#{self}: Task should be a task object or nil" unless task.is_a? Deployment::Task
        fail Deployment::InvalidArgument, "#{self}: Task #{task} is not found in the graph" unless graph.task_present? task
      end
      @task = task
    end

    def graph=(graph)
      fail Deployment::InvalidArgument, "#{self}: Graph should be a graph object" unless graph.is_a? Deployment::Graph
      graph.node = self
      @graph = graph
    end

    def create_new_graph
      self.graph = Deployment::Graph.new(self)
    end

    def to_s
      return "Node[#{id}]" if id == name
      "Node[#{id}/#{name}]"
    end

    def inspect
      message = "#{self} Status: #{status}"
      message += " Tasks: #{tasks_finished_count}/#{tasks_total_count}"
      message += " CurrentTask: #{task.name}" if task
      message
    end

    def method_missing(method, *args, &block)
      graph.send method, *args, &block
    end

    def run(task)
      raise Deployment::NotImplemented, 'This method is abstract and should be implemented in a subclass'
    end

    def poll
      raise Deployment::NotImplemented, 'This method is abstract and should be implemented in a subclass'
    end

  end
end
