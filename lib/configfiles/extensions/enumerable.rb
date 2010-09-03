module Enumerable
  def list_inspect(separator=', ')
    map{|x| x.inspect}.join(separator)
  end
end
