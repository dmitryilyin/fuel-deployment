module Deployment
  # This exception is raised if you have passed an incorrect object to a method
  class InvalidArgument < StandardError
  end

  # There is no task with such name is the graph
  class NoSuchTask < StandardError
  end

  # You have directly called an abstract method that should be implemented in a subclass
  class NotImplemented < StandardError
  end

  # Loop detected in the graph
  class LoopDetected < StandardError
  end
end
