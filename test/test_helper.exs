Application.put_env(
  :test_llm,
  :base_dir,
  Path.join([__DIR__, "support", "fixtures", "llm"])
)

ExUnit.start()
