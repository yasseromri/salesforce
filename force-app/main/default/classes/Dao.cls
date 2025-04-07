public interface Dao {
    Contact getById(Id id);
    List<Contact> getAll();
    void save(Contact entity);
    void updateEntity(Contact entity);
    void deleteEntity(Contact entity);
}