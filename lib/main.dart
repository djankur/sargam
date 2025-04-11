import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'taal_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(MaterialApp(
    home: NotesLyricsScreen(),
    theme: ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(
        primary: Colors.amber,
        secondary: Colors.amber.shade200,
        surface: Colors.grey.shade800,
        background: Colors.grey[900],
      ),
    ),
  ));
}

class NotesLyricsScreen extends StatefulWidget {
  @override
  _NotesLyricsScreenState createState() => _NotesLyricsScreenState();
}

class _NotesLyricsScreenState extends State<NotesLyricsScreen> {
  final List<Map<String, List<String>>> cycles = [];
  final AudioPlayer _tablaPlayer = AudioPlayer();
  final AudioPlayer _tanpuraPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  List<Taal> _taals = [];
  Taal? _selectedTaal;
  int _selectedGuun = 1;
  int bpm = 120;
  bool isRecording = false;
  String? _recordedFilePath;
  int _currentMatraIndex = -1;
  bool _isPlaying = false;
  final List<List<TextEditingController>> _swarganControllers = [];
  final List<List<TextEditingController>> _lyricsControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeCycles();
    _loadTaals();
    _initializeControllers();
  }

  @override
  void dispose() {
    _tablaPlayer.dispose();
    _tanpuraPlayer.dispose();
    for (var row in _swarganControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    for (var row in _lyricsControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _initializeCycles() {
    if (_selectedTaal == null) return;
    int totalMatras = _selectedTaal!.matras.length;
    cycles.clear();
    cycles.add({
      'Matras': _selectedTaal!.matras,
      'Notes': List.generate(totalMatras, (_) => ''),
      'Lyrics': List.generate(totalMatras, (_) => ''),
    });
    _initializeControllers();
    setState(() {});
  }

  Future<void> _loadTaals() async {
    _taals = await TaalService.loadTaals();
    setState(() {
      _selectedTaal = _taals.first;
      _selectedGuun = _selectedTaal!.guuns.first;
      _initializeCycles();
    });
  }

  void _initializeControllers() {
    if (cycles.isEmpty || _selectedTaal == null) return;
    int columns = _selectedTaal!.columns;
    List<String>? matras = cycles.first['Matras'];

    _swarganControllers.clear();
    _lyricsControllers.clear();

    for (int i = 0; i < matras!.length; i += columns) {
      List<TextEditingController> swarganRow = [];
      List<TextEditingController> lyricsRow = [];

      for (int j = 0; j < columns; j++) {
        int matraIndex = i + j;
        if (matraIndex >= matras.length) break;

        swarganRow.add(TextEditingController());
        lyricsRow.add(TextEditingController());
      }

      _swarganControllers.add(swarganRow);
      _lyricsControllers.add(lyricsRow);
    }
  }

  Future<void> playTablaBol(String soundFile) async {
    try {
      await _tablaPlayer.setAsset('assets/sound/$soundFile.mp3');
      await _tablaPlayer.play();
      await _tablaPlayer.seek(Duration.zero);
    } catch (e) {
      print('Error playing $soundFile: $e');
    }
  }

  Future<void> startTabla() async {
    if (_isPlaying || _selectedTaal == null) return;
    setState(() => _isPlaying = true);

    int delay = (60000 ~/ (bpm * _selectedGuun));

    for (int i = 0; i < _selectedTaal!.matras.length; i++) {
      if (!_isPlaying) break;
      setState(() => _currentMatraIndex = i);
      await playTablaBol(_selectedTaal!.matras[i].toLowerCase());
      await Future.delayed(Duration(milliseconds: delay));
    }

    setState(() {
      _isPlaying = false;
      _currentMatraIndex = -1;
    });
  }

  void stopTabla() {
    setState(() => _isPlaying = false);
    _tablaPlayer.stop();
  }

  Future<void> startTanpura() async {
    try {
      await _tanpuraPlayer.setAsset('assets/sound/tanpura.mp3');
      await _tanpuraPlayer.setLoopMode(LoopMode.one);
      await _tanpuraPlayer.play();
    } catch (e) {
      print('Error starting tanpura: $e');
    }
  }

  void stopTanpura() {
    _tanpuraPlayer.stop();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        Directory tempDir = await getApplicationDocumentsDirectory();
        _recordedFilePath = "${tempDir.path}/recording.m4a";
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordedFilePath!);
        setState(() => isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording started'),
            ));
        }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording failed: $e')),
          );
        }
      }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => isRecording = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording saved')),
    );
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath != null) {
      await _tablaPlayer.setFilePath(_recordedFilePath!);
      await _tablaPlayer.play();
    }
  }

  void _addCycle() {
    if (_selectedTaal == null) return;
    int totalMatras = _selectedTaal!.matras.length;
    cycles.add({
      'Matras': List.from(_selectedTaal!.matras),
      'Notes': List.generate(totalMatras, (_) => ''),
      'Lyrics': List.generate(totalMatras, (_) => ''),
    });
    setState(() {});
  }

  void _deleteCycle() {
    if (cycles.length > 1) {
      cycles.removeLast();
      setState(() {});
    }
  }

  Widget _buildTaalDropdown() {
    return DropdownButtonFormField<Taal>(
        value: _selectedTaal,
        decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12),
    ),
    dropdownColor: Colors.grey[850],
    style: TextStyle(color: Colors.white),
    onChanged: (newTaal) => setState(() {
    _selectedTaal = newTaal;
    _selectedGuun = _selectedTaal!.guuns.first;
    _initializeCycles();
    }),
    items: _taals.map((taal) => DropdownMenuItem(value: taal, child: Text(taal.name))).toList(),);
  }

  Widget _buildGuunDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedGuun,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      dropdownColor: Colors.grey[850],
      style: TextStyle(color: Colors.white),
      onChanged: (newGuun) => setState(() => _selectedGuun = newGuun!),
      items: _selectedTaal?.guuns.map((guun) => DropdownMenuItem(
        value: guun,
        child: Text('$guun', style: TextStyle(color: Colors.white)),
      )).toList() ?? [],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).primaryColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildMatraCard(int index) {
    if (cycles.isEmpty || _selectedTaal == null) return SizedBox();
    List<String> matras = cycles.first['Matras']!;
    List<String> notes = cycles.first['Notes']!;
    List<String> lyrics = cycles.first['Lyrics']!;

    return Card(
      elevation: 2,
      color: _currentMatraIndex == index
          ? Colors.amber.withOpacity(0.2)
          : Colors.grey[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _currentMatraIndex == index
              ? Colors.amber
              : Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(minHeight: 120), // Set minimum height
        child: Column(
          mainAxisSize: MainAxisSize.min, // Use minimum space needed
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(matras[index], style: TextStyle(
              color: _currentMatraIndex == index
                  ? Colors.amber
                  : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 4), // Reduced spacing
            Flexible( // Make text fields flexible
              child: TextField(
                controller: _swarganControllers[index ~/ _selectedTaal!.columns][index % _selectedTaal!.columns],
                onChanged: (value) => notes[index] = value,
                style: TextStyle(color: Colors.white, fontSize: 14), // Smaller font
                decoration: InputDecoration(
                  isDense: true, // Reduce padding
                  filled: true,
                  fillColor: Colors.grey[700],
                  hintText: "Swar",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            SizedBox(height: 4), // Reduced spacing
            Flexible( // Make text fields flexible
              child: TextField(
                controller: _lyricsControllers[index ~/ _selectedTaal!.columns][index % _selectedTaal!.columns],
                onChanged: (value) => lyrics[index] = value,
                style: TextStyle(color: Colors.white, fontSize: 14), // Smaller font
                decoration: InputDecoration(
                  isDense: true, // Reduce padding
                  filled: true,
                  fillColor: Colors.grey[700],
                  hintText: "Lyrics",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleCard(int cycleIndex) {
    if (cycles.isEmpty || _selectedTaal == null) return SizedBox();

    return Card(
      elevation: 4,
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withOpacity(0.3)),
      ),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Cycle ${cycleIndex + 1}", style: GoogleFonts.lato(
                  color: Colors.amber[200],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.amber),
                      onPressed: _addCycle,
                    ),
                    IconButton(
                      icon: Icon(Icons.remove, color: Colors.red[300]),
                      onPressed: _deleteCycle,
                    ),
                  ],
                ),
              ],
            ),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _selectedTaal!.columns,
                childAspectRatio: 0.8, // Reduced from 1.2 to give more width
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedTaal!.matras.length,
              itemBuilder: (context, index) => _buildMatraCard(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      elevation: 4,
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Controls", style: GoogleFonts.lato(
              color: Colors.amber[200],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildControlButton(
                  icon: Icons.play_arrow,
                  label: 'Start Tabla',
                  onPressed: startTabla,
                  color: Colors.green,
                ),
                _buildControlButton(
                  icon: Icons.stop,
                  label: 'Stop Tabla',
                  onPressed: stopTabla,
                  color: Colors.red,
                ),
                _buildControlButton(
                  icon: isRecording ? Icons.mic_off : Icons.mic,
                  label: isRecording ? 'Stop Rec' : 'Record',
                  onPressed: isRecording ? _stopRecording : _startRecording,
                  color: isRecording ? Colors.red : Colors.blue,
                ),
                _buildControlButton(
                  icon: Icons.play_circle_fill,
                  label: 'Play Recording',
                  onPressed: _playRecording,
                  color: Colors.purple,
                ),
                _buildControlButton(
                  icon: Icons.music_note,
                  label: 'Start Tanpura',
                  onPressed: startTanpura,
                  color: Colors.orange,
                ),
                _buildControlButton(
                  icon: Icons.music_off,
                  label: 'Stop Tanpura',
                  onPressed: stopTanpura,
                  color: Colors.red[300],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Taal Composer', style: GoogleFonts.lato(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Colors.amber[200],
        )),
        backgroundColor: Colors.grey[850],
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.amber[200]),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Taal selection card
            Card(
              elevation: 4,
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Select Taal', style: GoogleFonts.lato(
                      color: Colors.amber[200],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTaalDropdown()),
                        SizedBox(width: 16),
                        Expanded(child: _buildGuunDropdown()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // BPM control
            Card(
              elevation: 4,
              color: Colors.grey[850],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Tempo (BPM)', style: GoogleFonts.lato(
                      color: Colors.amber[200],
                      fontSize: 18,
                    )),
                    Slider(
                      min: 60,
                      max: 240,
                      divisions: 18,
                      label: '$bpm BPM',
                      value: bpm.toDouble(),
                      activeColor: Colors.amber,
                      inactiveColor: Colors.grey[700],
                      onChanged: (value) => setState(() => bpm = value.round()),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Cycles
            Text('Composition', style: GoogleFonts.lato(
              color: Colors.amber[200],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 12),
            ...List.generate(cycles.length, (index) => _buildCycleCard(index)),

            // Controls
            SizedBox(height: 24),
            _buildControlsCard(),
          ],
        ),
      ),
    );
  }
}