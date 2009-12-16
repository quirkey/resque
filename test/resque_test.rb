require File.dirname(__FILE__) + '/test_helper'

context "Resque" do
  setup do
    Resque.redis.flush_all

    Resque.push(:people, { 'name' => 'chris' })
    Resque.push(:people, { 'name' => 'bob' })
    Resque.push(:people, { 'name' => 'mark' })
  end

  test "can put jobs on a queue" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
  end

  test "can grab jobs off a queue" do
    Resque::Job.create(:jobs, 'some-job', 20, '/tmp')

    job = Resque.reserve(:jobs)

    assert_kind_of Resque::Job, job
    assert_equal SomeJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]
  end

  test "can re-queue jobs" do
    Resque::Job.create(:jobs, 'some-job', 20, '/tmp')

    job = Resque.reserve(:jobs)
    job.recreate

    assert_equal job, Resque.reserve(:jobs)
  end

  test "can put jobs on a queue by way of an ivar" do
    assert_equal 0, Resque.size(:ivar)
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')

    job = Resque.reserve(:ivar)

    assert_kind_of Resque::Job, job
    assert_equal SomeIvarJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]

    assert Resque.reserve(:ivar)
    assert_equal nil, Resque.reserve(:ivar)
  end

  test "jobs have a nice #inspect" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    job = Resque.reserve(:jobs)
    assert_equal '(Job{jobs} | SomeJob | [20, "/tmp"])', job.inspect
  end

  test "jobs can test for equality" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'some-job', 20, '/tmp')
    assert_equal Resque.reserve(:jobs), Resque.reserve(:jobs)

    assert Resque::Job.create(:jobs, 'SomeMethodJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert_not_equal Resque.reserve(:jobs), Resque.reserve(:jobs)

    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 30, '/tmp')
    assert_not_equal Resque.reserve(:jobs), Resque.reserve(:jobs)
  end

  test "can put jobs on a queue by way of a method" do
    assert_equal 0, Resque.size(:method)
    assert Resque.enqueue(SomeMethodJob, 20, '/tmp')
    assert Resque.enqueue(SomeMethodJob, 20, '/tmp')

    job = Resque.reserve(:method)

    assert_kind_of Resque::Job, job
    assert_equal SomeMethodJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]

    assert Resque.reserve(:method)
    assert_equal nil, Resque.reserve(:method)
  end

  test "needs to infer a queue with enqueue" do
    assert_raises Resque::NoQueueError do
      Resque.enqueue(SomeJob, 20, '/tmp')
    end
  end

  test "can put items on a queue" do
    assert Resque.push(:people, { 'name' => 'jon' })
  end
  
  test "putting on a queue should return a uuid" do
    id = Resque.push(:people, { 'name' => 'jon' })
    assert_match(/\w{32}/, id)
  end
  
  test "putting an item on the queue should insert the uuid into the payload" do
    id = Resque.push(:people, { 'name' => 'jon' })
  end
  
  test "can look up a specific job by uuid" do
    id = Resque.push(:people, { 'name' => 'jon' })
    assert_equal({ 'name' => 'jon' }, Resque.get(id))
  end
  
  test "can set and get status for a specific job by uuid" do
    id = Resque.push(:people, { 'name' => 'jon' })
    assert Resque.set_status(id, 'this job is working')
    assert_equal 'this job is working', Resque.get_status(id)
  end

  test "can pull items off a queue" do
    assert_equal({ 'name' => 'chris' }, Resque.pop(:people))
    assert_equal({ 'name' => 'bob' }, Resque.pop(:people))
    assert_equal({ 'name' => 'mark' }, Resque.pop(:people))
    assert_equal nil, Resque.pop(:people)
  end
  
  test "payload from pop should be an instance of Resque::Payload" do
    payload = Resque.pop(:people)
    assert payload.is_a?(Hash)
    assert payload.is_a?(Resque::Payload)
  end
  
  test "can set the uuid of a payload when initializing" do
    payload = Resque::Payload.new('12345', { 'name' => 'chris' })
    assert_equal 'chris', payload['name']
    assert '12345', payload.uuid
    
    payload = Resque::Payload.new({ 'name' => 'chris' })
    assert_equal 'chris', payload['name']
    assert_match /\w{32}/, payload.uuid
  end
  
  test "can get the uuid from the payload object" do
    payload = Resque.pop(:people)
    assert payload.uuid
  end
  
  test "can set the status of a job from the job instance" do
    id = Resque::Job.create(:jobs, PerformWithJob, 'resque bot')
    job = Resque::Job.reserve(:jobs)
    assert_equal PerformWithJob, job.payload_class
    assert job.status = "I'm working!"
    assert_equal "I'm working!", Resque.get_status(id)
  end
  
  test "can get the status of a job from the job instance" do
    id = Resque::Job.create(:jobs, PerformWithJob, 'resque bot')
    job = Resque::Job.reserve(:jobs)
    assert Resque.set_status(id, "I'm also working!")
    assert_equal "I'm also working!", job.status
  end

  test "knows how big a queue is" do
    assert_equal 3, Resque.size(:people)

    assert_equal({ 'name' => 'chris' }, Resque.pop(:people))
    assert_equal 2, Resque.size(:people)

    assert_equal({ 'name' => 'bob' }, Resque.pop(:people))
    assert_equal({ 'name' => 'mark' }, Resque.pop(:people))
    assert_equal 0, Resque.size(:people)
  end

  test "can peek at a queue" do
    assert_equal({ 'name' => 'chris' }, Resque.peek(:people))
    assert_equal 3, Resque.size(:people)
  end

  test "can peek multiple items on a queue" do
    assert_equal({ 'name' => 'bob' }, Resque.peek(:people, 1, 1))

    assert_equal([{ 'name' => 'bob' }, { 'name' => 'mark' }], Resque.peek(:people, 1, 2))
    assert_equal([{ 'name' => 'chris' }, { 'name' => 'bob' }], Resque.peek(:people, 0, 2))
    assert_equal([{ 'name' => 'chris' }, { 'name' => 'bob' }, { 'name' => 'mark' }], Resque.peek(:people, 0, 3))
    assert_equal({ 'name' => 'mark' }, Resque.peek(:people, 2, 1))
    assert_equal nil, Resque.peek(:people, 3)
    assert_equal [], Resque.peek(:people, 3, 2)
  end

  test "knows what queues it is managing" do
    assert_equal %w( people ), Resque.queues
    Resque.push(:cars, { 'make' => 'bmw' })
    assert_equal %w( cars people ), Resque.queues
  end

  test "queues are always a list" do
    Resque.redis.flush_all
    assert_equal [], Resque.queues
  end

  test "can delete a queue" do
    Resque.push(:cars, { 'make' => 'bmw' })
    assert_equal %w( cars people ), Resque.queues
    Resque.remove_queue(:people)
    assert_equal %w( cars ), Resque.queues
    assert_equal nil, Resque.pop(:people)
  end

  test "keeps track of resque keys" do
    assert_equal ["queue:people", "queues"], Resque.keys
  end
  
  test "badly wants a class name, too" do
    assert_raises Resque::NoClassError do
      Resque::Job.create(:jobs, nil)
    end
  end
  
  test "can perform jobs without args" do
    job = Resque::Job.new(:jobs, {'class' => 'JobWithoutArgs'})
    assert job
    assert job.perform
  end
  
  test "can perform jobs with args" do
    job = Resque::Job.new(:jobs, {'class' => 'GoodJob', 'args' => ['resque bot']})
    assert job
    assert_match(/resque bot/, job.perform)
  end
  
  test "can perform jobs on classes with perform_with_job" do
    job = Resque::Job.new(:jobs, {'class' => 'PerformWithJob', 'args' => ['resque bot']})
    assert job
    assert_match(/This is job (\w{32})/, job.perform)
  end

  test "keeps stats" do
    Resque::Job.create(:jobs, SomeJob, 20, '/tmp')
    Resque::Job.create(:jobs, BadJob)
    Resque::Job.create(:jobs, GoodJob)

    Resque::Job.create(:others, GoodJob)
    Resque::Job.create(:others, GoodJob)

    stats = Resque.info
    assert_equal 8, stats[:pending]

    @worker = Resque::Worker.new(:jobs)
    @worker.register_worker
    2.times { @worker.process }
    job = @worker.reserve
    @worker.working_on job

    stats = Resque.info
    assert_equal 1, stats[:working]
    assert_equal 1, stats[:workers]

    @worker.done_working

    stats = Resque.info
    assert_equal 3, stats[:queues]
    assert_equal 3, stats[:processed]
    assert_equal 1, stats[:failed]
    assert_equal ['localhost:9736'], stats[:servers]
  end
end