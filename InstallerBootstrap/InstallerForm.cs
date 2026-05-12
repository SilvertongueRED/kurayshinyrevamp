namespace InstallerBootstrap;

internal sealed class InstallerForm : Form
{
    private readonly InstallerOptions _initialOptions;
    private readonly List<Label> _wrappingLabels = [];
    private readonly TextBox _installPathTextBox;
    private readonly Label _statusLabel;
    private readonly Label _detailLabel;
    private readonly ProgressBar _progressBar;
    private readonly Button _installButton;
    private readonly Button _updateButton;
    private readonly Button _browseButton;
    private readonly Button _cancelButton;
    private CancellationTokenSource? _installCancellation;
    private bool _closeAfterInstallStops;
    private bool _allowClose;

    public InstallerForm(InstallerOptions options)
    {
        _initialOptions = options;

        Text = "Kuray Infinite Fusion Installer";
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(860, 430);
        MinimumSize = new Size(860, 430);
        FormBorderStyle = FormBorderStyle.Sizable;
        StartPosition = FormStartPosition.CenterScreen;
        MaximizeBox = false;
        MinimizeBox = false;
        Padding = new Padding(18);

        var contentLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 6,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        contentLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));

        var introLabel = CreateWrappingLabel(
            "Install / Repair sets up the current experimental tester build. If this folder only has the older public base release, the installer fetches that base first and then layers the current full update on top. Update Only skips the big base download and applies just the bundled current update to an existing install.",
            bottomMargin: 16);

        var pathLabel = new Label
        {
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 6),
            Text = "Game folder"
        };

        var pathLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 1,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            Margin = new Padding(0, 0, 0, 16)
        };
        pathLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        pathLayout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));

        _installPathTextBox = new TextBox
        {
            Dock = DockStyle.Fill,
            Margin = new Padding(0),
            Text = _initialOptions.TargetDirectory
        };

        _browseButton = CreateActionButton("Browse...", minimumWidth: 112);
        _browseButton.Margin = new Padding(12, 0, 0, 0);
        _browseButton.Click += BrowseButton_Click;

        pathLayout.Controls.Add(_installPathTextBox, 0, 0);
        pathLayout.Controls.Add(_browseButton, 1, 0);

        var modeHintLabel = CreateWrappingLabel(
            "Use Update Only when this folder already contains Game.exe plus the Data, Graphics, and Mods folders and you only want the current tester-build changes.",
            bottomMargin: 16);

        var progressLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            Margin = new Padding(0, 0, 0, 16)
        };
        progressLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));

        _statusLabel = new Label
        {
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 4),
            Text = _initialOptions.UpdateOnly ? "Ready to apply the latest update." : "Ready to install."
        };

        _detailLabel = new Label
        {
            AutoEllipsis = true,
            Dock = DockStyle.Fill,
            Height = 36,
            Margin = new Padding(0, 0, 0, 8),
            Text = string.Empty,
            TextAlign = ContentAlignment.MiddleLeft
        };

        _progressBar = new ProgressBar
        {
            Dock = DockStyle.Fill,
            Height = 20,
            Margin = new Padding(0),
            Style = ProgressBarStyle.Continuous
        };

        progressLayout.Controls.Add(_statusLabel, 0, 0);
        progressLayout.Controls.Add(_detailLabel, 0, 1);
        progressLayout.Controls.Add(_progressBar, 0, 2);

        var buttonLayout = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            FlowDirection = FlowDirection.RightToLeft,
            Margin = new Padding(0),
            WrapContents = false
        };

        _installButton = CreateActionButton("Install / Repair", minimumWidth: 150);
        _installButton.Click += InstallButton_Click;

        _updateButton = CreateActionButton("Update Only", minimumWidth: 126);
        _updateButton.Click += UpdateButton_Click;

        _cancelButton = CreateActionButton("Cancel", minimumWidth: 100);
        _cancelButton.Click += CancelButton_Click;

        buttonLayout.Controls.Add(_cancelButton);
        buttonLayout.Controls.Add(_updateButton);
        buttonLayout.Controls.Add(_installButton);

        contentLayout.Controls.Add(introLabel, 0, 0);
        contentLayout.Controls.Add(pathLabel, 0, 1);
        contentLayout.Controls.Add(pathLayout, 0, 2);
        contentLayout.Controls.Add(modeHintLabel, 0, 3);
        contentLayout.Controls.Add(progressLayout, 0, 4);
        contentLayout.Controls.Add(buttonLayout, 0, 5);

        Controls.Add(contentLayout);

        AcceptButton = _initialOptions.UpdateOnly ? _updateButton : _installButton;
        CancelButton = _cancelButton;

        FormClosing += InstallerForm_FormClosing;
        ClientSizeChanged += (_, _) => UpdateWrappingWidths(contentLayout.DisplayRectangle.Width);
        Shown += (_, _) => UpdateWrappingWidths(contentLayout.DisplayRectangle.Width);
    }

    private Label CreateWrappingLabel(string text, int bottomMargin)
    {
        var label = new Label
        {
            AutoSize = true,
            Dock = DockStyle.Fill,
            Margin = new Padding(0, 0, 0, bottomMargin),
            Text = text
        };

        _wrappingLabels.Add(label);
        return label;
    }

    private static Button CreateActionButton(string text, int minimumWidth)
    {
        return new Button
        {
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            Margin = new Padding(12, 0, 0, 0),
            MinimumSize = new Size(minimumWidth, 0),
            Padding = new Padding(14, 6, 14, 6),
            Text = text
        };
    }

    private void UpdateWrappingWidths(int availableWidth)
    {
        var wrappedWidth = Math.Max(240, availableWidth);
        foreach (var label in _wrappingLabels)
        {
            label.MaximumSize = new Size(wrappedWidth, 0);
        }
    }

    private void BrowseButton_Click(object? sender, EventArgs e)
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose where Kuray Infinite Fusion should be installed or updated.",
            SelectedPath = _installPathTextBox.Text,
            ShowNewFolderButton = true
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            _installPathTextBox.Text = dialog.SelectedPath;
        }
    }

    private async void InstallButton_Click(object? sender, EventArgs e)
    {
        await RunRequestedOperationAsync(updateOnly: false);
    }

    private async void UpdateButton_Click(object? sender, EventArgs e)
    {
        await RunRequestedOperationAsync(updateOnly: true);
    }

    private async Task RunRequestedOperationAsync(bool updateOnly)
    {
        var targetDirectory = _installPathTextBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(targetDirectory))
        {
            MessageBox.Show(this, "Choose a game folder first.", "Installer", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        if (updateOnly)
        {
            if (!ReleasePayloadManifest.LooksLikeGameInstall(targetDirectory))
            {
                MessageBox.Show(
                    this,
                    "Update Only needs an existing Kuray Infinite Fusion install folder. Choose the folder that already contains Game.exe plus the Data, Graphics, and Mods folders, or use Install / Repair instead.",
                    "Installer",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            var updateResult = MessageBox.Show(
                this,
                "Apply only the latest bundled changed files to this existing install?",
                "Installer",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);
            if (updateResult != DialogResult.Yes)
            {
                return;
            }
        }
        else if (Directory.Exists(targetDirectory) && Directory.EnumerateFileSystemEntries(targetDirectory).Any())
        {
            var overwriteResult = MessageBox.Show(
                this,
                "The target folder already contains files. Continue and overwrite matching files or download any missing base files?",
                "Installer",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);
            if (overwriteResult != DialogResult.Yes)
            {
                return;
            }
        }

        ToggleUi(isInstalling: true);
        _installCancellation = new CancellationTokenSource();
        _progressBar.Value = 0;
        _statusLabel.Text = updateOnly ? "Applying update..." : "Preparing installation...";
        _detailLabel.Text = targetDirectory;

        var progress = new Progress<InstallProgress>(UpdateProgress);
        var options = new InstallerOptions
        {
            TargetDirectory = targetDirectory,
            Silent = false,
            SkipShortcuts = false,
            UpdateOnly = updateOnly
        };

        try
        {
            await Task.Run(() => InstallerEngine.Install(options, progress, _installCancellation.Token));
            _statusLabel.Text = updateOnly ? "Update complete." : "Installation complete.";
            _detailLabel.Text = targetDirectory;

            var launchResult = MessageBox.Show(
                this,
                updateOnly
                    ? "Kuray Infinite Fusion was updated. Launch it now?"
                    : "Kuray Infinite Fusion is installed. Launch it now?",
                "Installer",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);

            if (launchResult == DialogResult.Yes)
            {
                var gamePath = Path.Combine(targetDirectory, "Game.exe");
                if (File.Exists(gamePath))
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = gamePath,
                        WorkingDirectory = targetDirectory,
                        UseShellExecute = true
                    });
                }
            }

            _allowClose = true;
            Close();
        }
        catch (OperationCanceledException)
        {
            _statusLabel.Text = updateOnly ? "Update canceled." : "Installation canceled.";
            _detailLabel.Text = "Temporary files cleaned up.";
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Installer Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            _statusLabel.Text = updateOnly ? "Update failed." : "Installation failed.";
            _detailLabel.Text = string.Empty;
        }
        finally
        {
            _installCancellation?.Dispose();
            _installCancellation = null;
            ToggleUi(isInstalling: false);
            if (_closeAfterInstallStops)
            {
                _closeAfterInstallStops = false;
                _allowClose = true;
                Close();
            }
        }
    }

    private void CancelButton_Click(object? sender, EventArgs e)
    {
        if (_installCancellation is not null)
        {
            RequestCancellation();
            return;
        }

        Close();
    }

    private void ToggleUi(bool isInstalling)
    {
        _installButton.Enabled = !isInstalling;
        _updateButton.Enabled = !isInstalling;
        _browseButton.Enabled = !isInstalling;
        _installPathTextBox.Enabled = !isInstalling;
        _cancelButton.Enabled = true;
        _cancelButton.Text = isInstalling ? "Stop" : "Cancel";
    }

    private void UpdateProgress(InstallProgress progress)
    {
        _statusLabel.Text = progress.Phase;
        _detailLabel.Text = progress.Detail;

        if (progress.TotalBytes <= 0)
        {
            _progressBar.Value = 0;
            return;
        }

        var percentage = (int)Math.Clamp(progress.ExtractedBytes * 100 / progress.TotalBytes, 0, 100);
        _progressBar.Value = percentage;
    }

    private void InstallerForm_FormClosing(object? sender, FormClosingEventArgs e)
    {
        if (_allowClose || _installCancellation is null)
        {
            return;
        }

        e.Cancel = true;
        _closeAfterInstallStops = true;
        RequestCancellation();
    }

    private void RequestCancellation()
    {
        if (_installCancellation is null || _installCancellation.IsCancellationRequested)
        {
            return;
        }

        _statusLabel.Text = "Canceling installation...";
        _detailLabel.Text = "Cleaning up temporary files...";
        _cancelButton.Enabled = false;
        _installCancellation.Cancel();
    }
}
