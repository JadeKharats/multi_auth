class MultiAuth::Provider::Github < MultiAuth::Provider
  def authorize_uri(scope = nil)
    client.get_authorize_uri("user:email")
  end

  def user(params : Hash(String, String))
    gh_user = fetch_gh_user(params["code"])

    user = User.new("github", gh_user.id, gh_user.name, gh_user.raw_json.as(String))

    user.email = gh_user.email
    user.nickname = gh_user.login
    user.location = gh_user.location
    user.description = gh_user.bio
    user.image = gh_user.avatar_url
    user.access_token = gh_user.access_token

    urls = {} of String => String
    urls["blog"] = gh_user.blog.as(String) if gh_user.blog
    urls["github"] = gh_user.html_url.as(String) if gh_user.html_url
    user.urls = urls unless urls.empty?

    user
  end

  private class GhUser
    property raw_json : String?
    property access_token : OAuth2::AccessToken?

    JSON.mapping(
      id: {type: String, converter: String::RawConverter},
      name: String,
      email: String,
      login: String,
      location: String?,
      bio: String?,
      avatar_url: String?,
      blog: String?,
      html_url: String?
    )
  end

  private def fetch_gh_user(code)
    access_token = client.get_access_token_using_authorization_code(code)

    api = HTTP::Client.new("api.github.com", tls: true)
    access_token.authenticate(api)

    raw_json = api.get("/user").body
    gh_user = GhUser.from_json(raw_json)
    gh_user.access_token = access_token
    gh_user.raw_json = raw_json
    gh_user
  end

  private def client
    OAuth2::Client.new(
      "github.com",
      client_id,
      client_secret,
      authorize_uri: "/login/oauth/authorize",
      token_uri: "/login/oauth/access_token"
    )
  end
end