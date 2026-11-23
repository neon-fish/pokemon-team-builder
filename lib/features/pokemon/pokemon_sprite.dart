import 'package:material_ui/material_ui.dart';

/// A Pokémon's picture, in a square of [size].
///
/// A faint ball icon is always drawn underneath. It is the placeholder while
/// the picture loads, and it stays if the picture is missing ([url] is null) or
/// fails to load, so there is never a broken-image box. The picture fades in.
class PokemonSprite extends StatelessWidget {
  const PokemonSprite({required this.url, this.size = 56, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    // The pictures can be much larger than they are shown. Decoding at the
    // size needed saves memory.
    final pixelWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: url == null ? 1 : 0.5,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.catching_pokemon,
              size: size * 0.5,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          if (url != null)
            Image.network(
              url,
              width: size,
              height: size,
              cacheWidth: pixelWidth,
              fit: BoxFit.contain,
              // The name is shown next to it, so there is nothing to announce.
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, loadedSynchronously) {
                if (loadedSynchronously || reduceMotion) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: child,
                );
              },
              // Show nothing, so the placeholder underneath stays visible.
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
