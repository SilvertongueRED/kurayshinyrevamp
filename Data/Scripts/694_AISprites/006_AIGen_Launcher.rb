#===============================================================================
# 694_AISprites - 006_AIGen_Launcher.rb
# Starts the bundled on-device sidecar on demand (Windows, via ShellExecute).
# Prefers a packaged Tools/sidecar.exe; falls back to Tools/sidecar_stub.py
# (dev, needs Python on PATH). All failures are swallowed -> graceful no-op.
#===============================================================================
module AIGen
  module Launcher
    module_function

    @last_attempt = nil

    def sidecar_exe; "Tools/sidecar.exe"; end
    def stub_py;     "Tools/sidecar_stub.py"; end
    def pkg_file(rel); "Tools/kif_neuralfusion/#{rel}"; end

    # After setup the sidecar runs from an isolated venv (no global Python
    # needed). Prefer the GPU training env once trained weights exist, else the
    # light runtime env.
    def best_venv_python
      weights = File.exist?(pkg_file("models/lora/pytorch_lora_weights.safetensors")) ||
                File.exist?(pkg_file("models/lora/pytorch_lora_weights.bin"))
      train = pkg_file(".venv-train/Scripts/python.exe")
      run   = pkg_file(".venv/Scripts/python.exe")
      return train if weights && File.exist?(train)
      return run if File.exist?(run)
      nil
    end

    # True when there is a real, set-up sidecar to launch (a packaged exe or a
    # bootstrapped venv with our sidecar). Used so the game never freezes waiting
    # on forks where the AI model was never installed.
    def launchable?
      File.exist?(sidecar_exe) || !best_venv_python.nil?
    end

    # Make sure the sidecar is reachable. Returns true if /health responds.
    # /health now comes up within ~1s of launch (the model warms in a background
    # thread inside the sidecar), so a short poll suffices; the generous ceiling
    # just covers a cold process start on a slow disk.
    def ensure_running(wait_seconds = 30)
      return true if AIGen::Backend.available?(true)
      return false unless launchable?
      launch!
      frames = wait_seconds * 20
      i = 0
      while i < frames
        (Graphics.update rescue nil)
        i += 1
        return true if (i % 10 == 0) && AIGen::Backend.available?(true)
      end
      AIGen::Backend.available?(true)
    end

    def launch!
      # debounce: don't spawn repeatedly within a few seconds
      if @last_attempt && (Time.now - @last_attempt) < 8
        return
      end
      @last_attempt = Time.now
      begin
        vpy = best_venv_python
        if File.exist?(sidecar_exe)
          shell_exec(sidecar_exe, "")
          AIGen.log("launching #{sidecar_exe}")
        elsif vpy
          shell_exec(File.expand_path(vpy), "\"#{File.expand_path(pkg_file('sidecar.py'))}\"")
          AIGen.log("launching venv sidecar #{vpy}")
        elsif File.exist?(stub_py)
          # first run, no venv yet: the stub self-creates the isolated env.
          r = shell_exec("python", "\"#{File.expand_path(stub_py)}\"")
          if !r || r.to_i <= 32
            shell_exec("py", "-3 \"#{File.expand_path(stub_py)}\"")
          end
          AIGen.log("bootstrapping sidecar via #{stub_py}")
        else
          AIGen.log("no sidecar found")
        end
      rescue => e
        AIGen.log("launch error: #{e.message}")
      end
    end

    # Hidden ShellExecute "open" (SW_HIDE=0). Falls back to `start`.
    def shell_exec(file, params)
      begin
        shellexec = Win32API.new('shell32', 'ShellExecute', 'LPPPPL', 'L')
        return shellexec.call(0, "open", file, params.to_s, File.expand_path("."), 0)
      rescue => e
        begin
          system("start \"\" \"#{file}\" #{params}")
          return 33
        rescue
          return 0
        end
      end
    end
  end
end
