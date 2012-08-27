shared_examples_for "integrating with a server" do
  def headerize(hash)
    Hash[hash.map do |k, v|
      ["HTTP_#{k.to_s.upcase}", v.to_s]
    end]
  end

  before :all do
    BatchApi.config.endpoint = "/batch"
    BatchApi.config.verb = :post
  end

  # these are defined in the dummy app's endpoints controller
  let(:get_headers) { {"foo" => "bar"} }
  let(:get_params) { {"other" => "value" } }

  let(:get_request) { {
    url: "/endpoint",
    method: "get",
    headers: get_headers,
    params: get_params
  } }

  let(:get_result) { {
    status: 422,
    body: {
      "result" => "GET OK",
      "params" => get_params
    },
    headers: { "GET" => "hello" }
  } }

  let(:parameter) {
    (rand * 10000).to_i
  }

  let(:parameter_request) { {
    url: "/endpoint/capture/#{parameter}",
    method: "get"
  } }

  let(:parameter_result) { {
    body: {
      "result" => parameter
    }
  } }

  # these are defined in the dummy app's endpoints controller
  let(:post_headers) { {"foo" => "bar"} }
  let(:post_params) { {"other" => "value"} }

  let(:post_request) { {
    url: "/endpoint",
    method: "post",
    headers: post_headers,
    params: post_params
  } }

  let(:post_result) { {
    status: 203,
    body: {
      "result" => "POST OK",
      "params" => post_params
    },
    headers: { "POST" => "guten tag" }
  } }

  let(:error_request) { {
    url: "/endpoint/error",
    method: "get"
  } }

  let(:error_response) { {
    status: 500,
    body: { "error" => { "message" => "StandardError" } }
  } }

  let(:missing_request) { {
    url: "/dont/work",
    method: "delete"
  } }

  let(:missing_response) { {
    status: 404,
    body: {}
  } }

  before :each do
    @t = Time.now
    xhr :post, "/batch", {
      ops: [
        get_request,
        post_request,
        error_request,
        missing_request
      ],
      sequential: true
    }.to_json, "CONTENT_TYPE" => "application/json"
  end

  it "returns a 200" do
    response.status.should == 200
  end

  it "includes results" do
    JSON.parse(response.body)["results"].should be_a(Array)
  end

  it "includes the timestamp" do
    JSON.parse(response.body)["timestamp"].to_i.should be_within(100).of(@t.to_i)
  end

  context "for a get request" do
    describe "the response" do
      before :each do
        @result = JSON.parse(response.body)["results"][0]
      end

      it "returns the body raw if decode_json_responses = false" do
        BatchApi.config.stub(:decode_json_responses).and_return(false)
        xhr :post, "/batch", {ops: [get_request], sequential: true}.to_json,
        "CONTENT_TYPE" => "application/json"
        @result = JSON.parse(response.body)["results"][0]
        @result["body"].should == get_result[:body].to_json
      end

      it "returns the body as objects if decode_json_responses = true" do
        @result = JSON.parse(response.body)["results"][0]
        @result["body"].should == get_result[:body]
      end

      it "returns the expected status" do
        @result["status"].should == get_result[:status]
      end

      it "returns the expected headers" do
        @result["headers"].should include(get_result[:headers])
      end

      it "verifies that the right headers were received" do
        @result["headers"]["REQUEST_HEADERS"].should include(
          headerize(get_headers)
        )
      end
    end
  end

  context "for a request with parameters" do
    describe "the response" do
      before :each do
        @result = JSON.parse(response.body)["results"][5]
      end

      it "properly parses the URL segment as a paramer" do
        @result = JSON.parse(response.body)["results"][0]
        @result["body"].should == parameter_result[:body]
      end
    end
  end
  context "for a post request" do
    describe "the response" do
      before :each do
        @result = JSON.parse(response.body)["results"][1]
      end

      it "returns the body raw if decode_json_responses = false" do
        # BatchApi.config.decode_bodies = false
        xhr :post, "/batch", {ops: [post_request], sequential: true}.to_json,
          "CONTENT_TYPE" => "application/json"
        @result = JSON.parse(response.body)["results"][0]
        @result["body"].should == JSON.parse(post_result[:body].to_json)
      end

      it "returns the body as objects if decode_json_responses = true" do
        @result["body"].should == post_result[:body]
      end

      it "returns the expected status" do
        @result["status"].should == post_result[:status]
      end

      it "returns the expected headers" do
        @result["headers"].should include(post_result[:headers])
      end

      it "verifies that the right headers were received" do
        @result["headers"]["REQUEST_HEADERS"].should include(headerize(post_headers))
      end
    end
  end

  context "for a request that returns an error" do
    before :each do
      @result = JSON.parse(response.body)["results"][2]
    end

    it "returns the right status" do
      @result["status"].should == error_response[:status]
    end

    it "returns the right status" do
      @result["body"].should == error_response[:body]
    end
  end

  context "for a request that returns error" do
    before :each do
      @result = JSON.parse(response.body)["results"][3]
    end

    it "returns the right status" do
      @result["status"].should == 404
    end
  end
end
