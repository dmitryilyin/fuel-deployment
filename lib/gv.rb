require 'graphviz'

module Deployment
  module GV

    def gv_filter_node=(value)
      @gv_filter_node = value
    end

    def gv_filter_node
      @gv_filter_node
    end

    def gv_graph_name
      return name if respond_to? :name
      return id if respond_to? :id
      'graph'
    end

    def gv_task_name(task)
      return task unless task.is_a? Deployment::Task
      return task.name if gv_filter_node
      "#{task.node.name}_#{task.name}"
    end

    def gv_task_color(task)
      return :orange if task.dependencies_have_failed? and not task.status == :failed
      return :yellow if task.dependencies_are_ready? and task.status == :pending

      case task.status
        when :pending;
          :white
        when :successful;
          :green
        when :failed;
          :red
        when :skipped;
          :purple
        when :running;
          :blue
        else
          :white
      end
    end

    def gv_reset
      @gv_object = nil
    end

    def gv_object
      return @gv_object if @gv_object
      @gv_object = GraphViz.new gv_graph_name, :type => :digraph
      @gv_object.node_attrs[:style] = 'filled, solid'

      each_task do |task|
        next unless task.node == gv_filter_node if gv_filter_node
        gv_node = @gv_object.add_node gv_task_name(task)
        gv_node.fillcolor = gv_task_color(task)
      end

      each_task do |task|
        task.each_dependency do |dep_task|
          next unless dep_task.node == gv_filter_node if gv_filter_node
          next unless @gv_object.find_node gv_task_name(dep_task) and @gv_object.find_node gv_task_name(task)
          @gv_object.add_edges gv_task_name(dep_task), gv_task_name(task)
        end
      end
      @gv_object
    end

    def to_dot
      return unless gv_object
      gv_object.to_s
    end

    def gv_make_image
      return unless gv_object
      gv_object.output(:svg => "#{gv_object.name}.svg")
    end
  end
end
