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
      return name if respond_to? :name and name
      return id if respond_to? :id and id
      'graph'
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
        gv_node = @gv_object.add_node task.to_s
        gv_node.fillcolor = gv_task_color(task)
      end

      each_task do |task|
        task.each_dependency do |dep_task|
          next unless dep_task.node == gv_filter_node if gv_filter_node
          next unless @gv_object.find_node dep_task.to_s and @gv_object.find_node task.to_s
          @gv_object.add_edges dep_task.to_s, task.to_s
        end
      end
      @gv_object
    end

    def to_dot
      return unless gv_object
      gv_object.to_s
    end

    def gv_make_step_image
      gv_reset
      return unless gv_object
      @step = 1 unless @step
      name = "#{gv_object.name}-#{@step}"
      file = gv_make_image name
      @step += 1
      gv_reset
      file
    end

    def gv_make_image(name=nil)
      return unless gv_object
      name = gv_object.name unless name
      file = "#{name}.svg"
      gv_object.output(:svg => file)
      file
    end
  end
end
