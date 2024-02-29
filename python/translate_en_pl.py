import os
import re
from argostranslate import translate

def load_translation(from_lang_code, to_lang_code):
    installed_languages = translate.get_installed_languages()
    from_lang = next((lang for lang in installed_languages if lang.code == from_lang_code), None)
    to_lang = next((lang for lang in installed_languages if lang.code == to_lang_code), None)

    if from_lang and to_lang:
        return from_lang.get_translation(to_lang)

    raise Exception(f"Translation package for {from_lang_code} to {to_lang_code} not found")

def translate_text(text, translation):
    return translation.translate(text)

source_directory = '/var/www/opencart/catalog/language/en-gb/'
target_directory = '/var/www/opencart/catalog/language/pl-pl/'

translation = load_translation("en", "pl")

os.makedirs(target_directory, exist_ok=True)

for subdir, dirs, files in os.walk(source_directory):
    for filename in files:
        if filename.endswith('.php'):
            source_path = os.path.join(subdir, filename)
            target_subdir = subdir.replace(source_directory, target_directory)
            os.makedirs(target_subdir, exist_ok=True)
            target_path = os.path.join(target_subdir, filename)

            print(f"Processing file: {source_path} => {target_path}")

            with open(source_path, 'r', encoding='utf-8') as file:
                content = file.readlines()

            translated_content = []

            translation_pattern = re.compile(r"\$_\['[^']+'\]\s*=\s*'[^']+")

            for line in content:
                if translation_pattern.match(line) and not line.strip().startswith('//'):
                    key, value = line.split('=', 1)
                    original_text = value.strip(" ;\n\"'")
                    translated_part = translate_text(original_text, translation)
                    print(f'Original: {original_text} | Translated: {translated_part}')
                    translated_line = key + '= "' + translated_part + "\";\n"
                    translated_content.append(translated_line)
                else:
                    translated_content.append(line)

            with open(target_path, 'w', encoding='utf-8') as file:
                file.writelines(translated_content)

            print(f'Translated {filename}')
