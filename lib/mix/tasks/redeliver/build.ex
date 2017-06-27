defmodule Mix.Tasks.Redeliver.Build do
  use Mix.Task

  @shortdoc "Build a release on the build server"

  @build_server "104.131.105.21"
  @build_user   "root"
  @git_branch   "master"
  @timeout      5_000

  def run(_args) do
    :ssh.start

    directory = File.cwd! |> Path.basename
    tarball   = "#{directory}.tar.gz"
    {:ok, channel, connection} = :ssh_sftp.start_channel(
      to_charlist(@build_server),
      silently_accept_hosts: true,
      user:                  to_charlist(@build_user)
    )
    {:ok, file} = :ssh_sftp.open(
      channel,
      to_charlist(tarball),
      ~w[write]a,
      @timeout
    )
    Port.open(
      {
        :spawn,
        "git archive --prefix #{directory}/ --format tar.gz #{@git_branch}"
      },
      ~w[binary exit_status]a
    )
    |> Stream.unfold(
      fn port ->
        receive do
          {^port, {:data, data}} ->
            {data, port}
          {^port, {:exit_status, _status}} ->
            nil
        end
      end
    )
    |> Enum.each(fn data ->
      :ok = :ssh_sftp.write(channel, file, data, @timeout)
    end)
    :ok = :ssh_sftp.close(channel, file, @timeout)
    :ok = :ssh_sftp.stop_channel(channel)

    {:ok, channel} = :ssh_connection.session_channel(connection, @timeout)
    :success = :ssh_connection.exec(
      connection,
      channel,
      to_charlist("tar xzf #{tarball}"),
      @timeout
    )
    Stream.unfold({connection, channel}, fn {conn, chan} ->
      receive do
        {:ssh_cm, ^conn, {:closed, ^chan}} ->
          {:ok, {conn, chan}}
        {:ssh_cm, ^conn, _message} ->
          nil
      end
    end)
    |> Stream.run

    :ok = :ssh.close(connection)
  end
end
