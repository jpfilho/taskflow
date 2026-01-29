class MediaAlbumsValidators {
  /// Valida se o título não está vazio
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'O título é obrigatório';
    }
    if (value.length > 200) {
      return 'O título deve ter no máximo 200 caracteres';
    }
    return null;
  }

  /// Valida se pelo menos um nível da hierarquia foi selecionado
  static String? validateHierarchy({
    String? segmentId,
    String? equipmentId,
    String? roomId,
  }) {
    if (segmentId == null && equipmentId == null && roomId == null) {
      return 'Selecione pelo menos um Segmento, Equipamento ou Sala';
    }
    return null;
  }

  /// Valida se há imagens selecionadas
  static String? validateImages(List<dynamic> images) {
    if (images.isEmpty) {
      return 'Selecione pelo menos uma imagem';
    }
    if (images.length > 50) {
      return 'Máximo de 50 imagens por vez';
    }
    return null;
  }

  /// Valida tags (máximo de 20 tags, cada uma com até 30 caracteres)
  static String? validateTags(List<String> tags) {
    if (tags.length > 20) {
      return 'Máximo de 20 tags';
    }
    for (final tag in tags) {
      if (tag.trim().isEmpty) {
        return 'Tags não podem estar vazias';
      }
      if (tag.length > 30) {
        return 'Cada tag deve ter no máximo 30 caracteres';
      }
    }
    return null;
  }
}
