import 'package:flutter/material.dart';
import 'video_player_screen.dart';
import 'model/json_conversion_model.dart' as model;

class ChannelListScreen extends StatelessWidget {
  final List<model.Stream> channels;

  const ChannelListScreen({super.key, required this.channels});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Live Channels")),
      body: ListView.builder(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ListTile(
              title: Text(channel.title ?? "Unnamed Channel"),
              subtitle: Text(channel.quality ?? ""),
              trailing: Icon(Icons.play_circle_fill, color: Colors.green),
              onTap: () {
                if (channel.url != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        title: channel.title ?? "Channel",
                        streamUrl: channel.url!,
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
