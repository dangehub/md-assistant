import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/screens/init/cubit/init_cubit.dart';
import 'package:obsi/src/widgets/obsi_title.dart';
import 'package:url_launcher/url_launcher.dart';

class Init extends StatefulWidget {
  final InitCubit _initCubit;
  const Init(this._initCubit, {Key? key}) : super(key: key);

  @override
  State<Init> createState() => _InitState();
}

class _InitState extends State<Init> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget._initCubit.startScanning(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const ObsiTitle()),
        body: SafeArea(
            bottom: true,
            child: BlocBuilder<InitCubit, InitState>(
                bloc: widget._initCubit,
                builder: (context, state) {
                  return Center(
                      child: SingleChildScrollView(
                          child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                              "Pick the folder where your Obsidian vault is stored.\n\nVaultMate needs this to find and show your tasks.",
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          _buildContentForState(context, state),
                          const SizedBox(height: 24),
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(children: [
                                const Text("Contact the developer:"),
                                GestureDetector(
                                  onTap: () {
                                    _launchEmail(context);
                                  },
                                  child: const Text("support@vaultmate.app",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 16,
                                        decoration: TextDecoration.underline,
                                      )),
                                )
                              ]))
                        ]),
                  )));
                })));
  }

  Widget _buildContentForState(BuildContext context, InitState state) {
    if (state is InitScanning) {
      return Column(
        children: const [
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Searching for your vaults..."),
        ],
      );
    }

    if (state is InitScanResults) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Select one of the vaults we found:",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.vaultPaths.length,
              itemBuilder: (context, index) {
                final path = state.vaultPaths[index];
                final name = path.split('/').where((e) => e.isNotEmpty).last;
                return Card(
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(path),
                    onTap: () =>
                        widget._initCubit.selectScannedVault(context, path),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildManualSelectionSection(context, state),
        ],
      );
    }

    if (state is InitError) {
      return Column(
        children: [
          Text(
            'Error while searching for vaults: ${state.message}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => widget._initCubit.startScanning(context),
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 16),
          _buildManualSelectionSection(context, state),
        ],
      );
    }

    // InitInitial, InitNoVaultsFound, ChosenDirectory
    return _buildManualSelectionSection(context, state);
  }

  Widget _buildManualSelectionSection(BuildContext context, InitState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state is InitNoVaultsFound)
          const Text(
            "We could not find any Obsidian vaults automatically.",
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        Text(
          widget._initCubit.vaultDirectory ?? "<Please choose the folder>",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => widget._initCubit.selectDirectory(context),
          child: const Text("Select Folder Manually"),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: state is ChosenDirectory
              ? () => widget._initCubit.continuePressed(context)
              : null,
          child: const Text("Continue"),
        ),
      ],
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: "support@vaultmate.app",
      query: 'subject=VaultMate', // Optional query parameters
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $emailUri')),
      );
    }
  }
}
