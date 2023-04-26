class Hl7::NewPatient
  def self.call
    rsa_private = OpenSSL::PKey::RSA.new(File.read('privatekey.pem'))

    payload = {
      "iss": "420b602a-38af-4ab7-8479-ab188526a68f",
      "sub": "420b602a-38af-4ab7-8479-ab188526a68f",
      "aud": "https://fhir.epic.com/interconnect-fhir-oauth/oauth2/token",
      "jti": SecureRandom.hex,
      "exp": (DateTime.now + 4.minutes).to_i
    }
    token = JWT.encode payload, rsa_private, 'RS256'
    response = Faraday.post("https://fhir.epic.com/interconnect-fhir-oauth/oauth2/token") do |request|
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form({
       grant_type: 'client_credentials',
       client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
       client_assertion: token
      })
    end

    response.body
  end
end
