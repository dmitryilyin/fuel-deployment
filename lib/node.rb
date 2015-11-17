module Deployment
  class Node
    ALLOWED_STATUSES = [:online, :busy, :offline, :failed, :successful]

    def initialize(name)
      @name = name
      @status = :online
      @task = nil
      create_new_graph
    end

    include Enumerable

    attr_reader :status
    attr_reader :name
    attr_reader :task
    attr_reader :graph

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
      fail Deployment::InvalidArgument, "#{self}: Task should be a task object or nil" unless task.is_a? Deployment::Task or task.nil?
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

    def each_task(&block)
      graph.each(&block)
    end
    alias :each :each_task

    def debug(message)
      log "#{self}: #{message}"
    end

    def to_s
      "Node[#{name}]"
    end

    def inspect
      message = "#{self} Status: #{status}"
      message += " Task: #{task.name}" if task
      message
    end

    def tasks_are_finished?
      graph.tasks_are_finished?
    end
    alias :finished? :tasks_are_finished?

    def tasks_are_successful?
      graph.tasks_are_successful?
    end
    alias :successful? :tasks_are_successful?

    def tasks_have_failed?
      graph.tasks_have_failed?
    end
    alias :failed? :tasks_have_failed?

    def ready_task
      graph.ready_task
    end
    alias :next_task :ready_task

    def task_get(task_name)
      graph.task_get task_name
    end
    alias :get_task :task_get
    alias :[] :task_get

    def log(message)
      # override this in a subclass
      puts message
    end

    def run(task)
      # override this in a subclass
      fail Deployment::InvalidArgument, "#{self}: Node can run only tasks" unless task.is_a? Deployment::Task
      debug "Run task: #{task}"
      self.task = task
      self.status = :busy
    end

    def poll
      # override this in a subclass
      debug 'Poll node status'
      self.task.status = :successful if busy?
      self.status = :online
    end

  end
end
